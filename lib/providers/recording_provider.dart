// lib/providers/recording_provider.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../models/recording.dart';
import '../models/recording_settings.dart';
import '../services/audio_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/connectivity_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/storage_service.dart';
import '../services/sync_queue_service.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';

// ─── Service providers ─────────────────────────────────────────────────────────

final audioServiceProvider = Provider((ref) => AudioService());
final storageServiceProvider = Provider((ref) => StorageService());

// ─── Recording state notifier ──────────────────────────────────────────────────

/// Manages the list of recordings and coordinates between local Hive storage
/// and Firestore real-time sync.
class RecordingNotifier extends StateNotifier<List<Recording>> {
  final AudioService _audioService;
  final StorageService _storageService;
  final CloudSyncService _cloudSyncService;
  final FirebaseStorageService _firebaseStorageService;

  /// Null means the user is not signed in — Hive-only mode.
  final String? _userId;
  final ConnectivityService _connectivity;
  final SyncQueueService _syncQueue;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  bool _isRecording = false;

  RecordingNotifier({
    required AudioService audioService,
    required StorageService storageService,
    required CloudSyncService cloudSyncService,
    required FirebaseStorageService firebaseStorageService,
    required String? userId,
    required ConnectivityService connectivity,
    required SyncQueueService syncQueue,
  })  : _audioService = audioService,
        _storageService = storageService,
        _cloudSyncService = cloudSyncService,
        _firebaseStorageService = firebaseStorageService,_connectivity = connectivity,
        _syncQueue = syncQueue,
        _userId = userId,
        super([]) {
    if (_userId != null) {
      _subscribeToFirestore();
    } else {
      _loadFromHive();
    }
  }

  bool get isRecording => _isRecording;

  @override
  void dispose() {
    _firestoreSub?.cancel();
    super.dispose();
  }

  // ─── Firestore stream ─────────────────────────────────────────

  void _subscribeToFirestore() {
    // Show local data immediately while the network call loads
    _loadFromHive();

    _firestoreSub = _cloudSyncService
        .watchRecordingsSnapshot()
        .listen(_onFirestoreSnapshot, onError: (Object e) {
      debugPrint('⚠️ Firestore recordings stream error: $e');
      // Do not crash — local Hive state is still valid
    });
  }

  /// Handles a Firestore snapshot event.
  Future<void> _onFirestoreSnapshot(
      QuerySnapshot<Map<String, dynamic>> snapshot) async {
    if (!mounted) return;

    if (snapshot.docChanges.isEmpty) return;

    final localMap = {for (final r in state) r.id: r};

    for (final change in snapshot.docChanges) {
      final id = change.doc.id;

      switch (change.type) {
        case DocumentChangeType.removed:
          localMap.remove(id);
          _storageService.deleteRecording(id).ignore();

        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          final cloudRec = Recording.fromJson(change.doc.data()!);
          final existing = localMap[id];

          final merged = cloudRec.copyWith(
            filePath: existing?.filePath.isNotEmpty == true
                ? existing!.filePath
                : cloudRec.filePath,
            waveformData: existing?.waveformData ?? cloudRec.waveformData,
          );

          localMap[id] = merged;
          _storageService.updateRecording(merged).ignore();
      }
    }

    if (!mounted) return;
    state = _sortRecordings(localMap.values);
  }

  // ─── Hive (offline / unregistered) ───────────────────────────

  Future<void> _loadFromHive() async {
    final recordings = await _storageService.getAllRecordings();
    if (mounted) state = recordings;
  }

  // ─── Sort helper ──────────────────────────────────────────────

  List<Recording> _sortRecordings(Iterable<Recording> recordings) {
    final list = recordings.toList();
    final pinned = list.where((r) => r.isPinned).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final unpinned = list.where((r) => !r.isPinned).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [...pinned, ...unpinned];
  }

  // ─── Recording lifecycle ──────────────────────────────────────

  Future<void> startRecording(RecordingSettings settings) async {
    await _audioService.startRecording(settings);
    _isRecording = true;
  }

  Future<void> stopRecording() async {
    final recording = await _audioService.stopRecording();
    _isRecording = false;
    
    if (recording != null) {
      // Pre-calculate waveform data before saving
      final waveform = await _audioService.extractWaveformData(recording.filePath);
      final enrichedRecording = recording.copyWith(waveformData: waveform);

      // 1. Persist locally
      await _storageService.saveRecording(enrichedRecording);
      
      // 2. Optimistic UI update
      await _loadFromHive();
      
      // 3. Push to Firestore
      _cloudSyncService.syncRecordingToCloud(enrichedRecording).catchError((e) {
        debugPrint('⚠️ stopRecording: Firestore sync deferred (offline?): $e');
      });
    }
  }

  /// Downloads the audio file for [recording] from Firebase Storage to local
  /// storage, then updates the recording's [filePath] in Hive and state so
  /// playback works immediately.
  Future<String?> downloadAudioLocally(
      Recording recording, {
        void Function(double progress)? onProgress,
      }) async {
    if (!recording.isBackedUp) return null;

    try {
      final localPath = await _firebaseStorageService.downloadRecording(
        recording.backupUrl!,
        recording.id,
        recording.fileName,
      );

      if (localPath != null) {
        // If we just downloaded it, extract waveform now too
        final waveform = await _audioService.extractWaveformData(localPath);
        final updated = recording.copyWith(filePath: localPath, waveformData: waveform);
        
        await _storageService.updateRecording(updated);
        // Update in-memory state
        state = _sortRecordings(
          state.map((r) => r.id == recording.id ? updated : r),
        );
      }

      return localPath;
    } catch (e) {
      debugPrint('❌ downloadAudioLocally error for ${recording.id}: $e');
      rethrow;
    }
  }

  Future<void> pauseRecording() async => _audioService.pauseRecording();
  Future<void> resumeRecording() async => _audioService.resumeRecording();

  Future<void> discardRecording() async {
    await _audioService.discardRecording();
    _isRecording = false;
  }

  Future<void> deleteRecording(String id) async {
    final recording = state.firstWhere((r) => r.id == id);

    state = state.where((r) => r.id != id).toList();

    await _audioService.deleteRecording(recording.filePath);
    await _storageService.deleteRecording(id);

    if (recording.isBackedUp) {
      await _firebaseStorageService.deleteRecording(id);
    }
    await _cloudSyncService.deleteRecordingFromCloud(id);
  }

  Future<void> updateRecording(Recording recording) async {
    await _storageService.updateRecording(recording);

    state = _sortRecordings(
      state.map((r) => r.id == recording.id ? recording : r),
    );

    await _cloudSyncService.syncRecordingToCloud(recording);
  }

  Future<void> toggleFavorite(String id) async {
    final recording = state.firstWhere((r) => r.id == id);
    await updateRecording(
        recording.copyWith(isFavorite: !recording.isFavorite));
  }

  Future<void> togglePin(String id) async {
    final recording = state.firstWhere((r) => r.id == id);
    await updateRecording(recording.copyWith(isPinned: !recording.isPinned));
  }

  Future<void> refreshRecordings() async => _loadFromHive();

  // ─── Cloud backup ─────────────────────────────────────────────

  Future<String?> backupRecording(
      Recording recording, {
        void Function(double progress)? onProgress,
      }) async {
    final downloadUrl = await _firebaseStorageService.uploadRecording(
      recording.filePath,
      recording.id,
      onProgress: onProgress,
    );

    if (downloadUrl != null) {
      final updated = recording.copyWith(backupUrl: downloadUrl);
      await updateRecording(updated);
    }

    return downloadUrl;
  }

  // ─── Sync queue drain ─────────────────────────────────────────

  Future<void> drainSyncQueue({
    void Function(String recordingId)? onJobComplete,
  }) async {
    if (!_connectivity.isOnline) return;

    final pending = _syncQueue.peekAll();
    if (pending.isEmpty) return;

    debugPrint('📤 Draining sync queue: ${pending.length} job(s)');

    for (final job in pending) {
      try {
        final matches = state.where((r) => r.id == job.recordingId).toList();
        if (matches.isEmpty) {
          await _syncQueue.remove(job.recordingId);
          continue;
        }
        final recording = matches.first;

        final downloadUrl = await _firebaseStorageService.uploadRecording(
          recording.filePath,
          recording.id,
        );

        if (downloadUrl != null) {
          final updated = recording.copyWith(backupUrl: downloadUrl);
          await _storageService.updateRecording(updated);
          await _cloudSyncService.syncRecordingToCloud(updated);
          await _syncQueue.remove(job.recordingId);
          onJobComplete?.call(job.recordingId);
          debugPrint('✅ Sync queue: processed ${job.recordingId}');
        }
      } on OfflineException {
        debugPrint('⚠️ Sync queue: went offline again, stopping drain');
        break;
      } on TransferInterruptedException {
        debugPrint('⚠️ Sync queue: transfer interrupted, stopping drain');
        break;
      } catch (e) {
        debugPrint('❌ Sync queue: error processing ${job.recordingId}: $e');
      }
    }
  }

  // ─── Cloud restore  (first login) ────────────────────────────

  Future<void> restoreFromCloud({bool autoDownloadAudio = false}) async {
    final cloudRecordings = await _cloudSyncService.restoreFromCloud(
      storageService: _firebaseStorageService,
      localStorageService: _storageService,
      autoDownloadAudio: autoDownloadAudio,
    );

    if (cloudRecordings.isEmpty) return;

    final merged = <String, Recording>{
      for (final r in state) r.id: r,
      for (final r in cloudRecordings) r.id: r,
    };

    state = _sortRecordings(merged.values);
  }
}

// ─── Providers ─────────────────────────────────────────────────────────────────

final recordingProvider =
StateNotifierProvider<RecordingNotifier, List<Recording>>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.uid;

  final audioService = ref.watch(audioServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  final cloudSyncService = ref.watch(cloudSyncServiceProvider);
  final firebaseStorageService = ref.watch(firebaseStorageServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final syncQueue = ref.watch(syncQueueServiceProvider);

  return RecordingNotifier(
    audioService: audioService,
    storageService: storageService,
    cloudSyncService: cloudSyncService,
    firebaseStorageService: firebaseStorageService,
    userId: userId,
    connectivity: connectivity,
    syncQueue: syncQueue,
  );
});

final isRecordingProvider = Provider<bool>((ref) {
  return ref.watch(recordingProvider.notifier).isRecording;
});

final pinnedRecordingsProvider = FutureProvider<List<Recording>>((ref) async {
  final recordings = ref.watch(recordingProvider);
  return recordings.where((r) => r.isPinned).toList();
});

final favoriteRecordingsProvider =
FutureProvider<List<Recording>>((ref) async {
  final recordings = ref.watch(recordingProvider);
  return recordings.where((r) => r.isFavorite).toList();
});

/// Provider for available audio input devices.
final audioInputDevicesProvider = FutureProvider<List<InputDevice>>((ref) async {
  final audioService = ref.watch(audioServiceProvider);
  return audioService.listInputDevices();
});

// ─── Backup progress ───────────────────────────────────────────────────────────

final backupProgressProvider =
StateProvider.family<double?, String>((ref, recordingId) => null);
