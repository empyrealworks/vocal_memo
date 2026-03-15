// lib/providers/recording_provider.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
///
/// ## Data flow (registered users)
///
///   Write path  : UI calls a mutating method (e.g. [updateRecording])
///                 → Hive updated immediately (optimistic, no round-trip wait)
///                 → state updated immediately (UI sees change at once)
///                 → Firestore written asynchronously
///                 → Firestore stream fires on ALL devices (including this one)
///                 → [_onFirestoreSnapshot] merges the echo idempotently
///
///   Remote change: Another device writes to Firestore
///                  → Firestore stream fires on THIS device
///                  → [_onFirestoreSnapshot] merges with local state,
///                    preserving this device's filePath / waveformData
///                  → state updated → UI rebuilds
///
/// ## Data flow (unregistered users)
///
///   All operations use Hive only. No Firestore connection is opened.
///
/// ## Firestore cost notes
///
///   - One `snapshots()` listener per user session (not per screen/widget).
///   - Initial load: 1 read per document in the collection.
///   - Each subsequent event: 1 read per *changed* document only.
///   - Listener is cancelled in [dispose] — called when the provider is
///     rebuilt due to auth state change (sign-in / sign-out).
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
  ///
  /// Uses [QuerySnapshot.docChanges] to process only the delta:
  ///   - Added / modified documents → merge with local state
  ///   - Removed documents → remove from state and Hive
  ///
  /// Merge strategy for added/modified records:
  ///   - [filePath]     : local value wins (device-specific absolute path)
  ///   - [waveformData] : local value wins (generated from the local audio file)
  ///   - Everything else: cloud value wins (title, transcript, pin, etc.)
  Future<void> _onFirestoreSnapshot(
      QuerySnapshot<Map<String, dynamic>> snapshot) async {
    if (!mounted) return;

    // Nothing changed — Firestore fires an initial empty event sometimes
    if (snapshot.docChanges.isEmpty) return;

    // Build a fast lookup of the current in-memory state
    final localMap = {for (final r in state) r.id: r};

    // Track which IDs were removed on the cloud side
    final removedIds = <String>{};

    for (final change in snapshot.docChanges) {
      final id = change.doc.id;

      switch (change.type) {
        case DocumentChangeType.removed:
          removedIds.add(id);
          localMap.remove(id);
          // Remove from Hive cache too — fire-and-forget
          _storageService.deleteRecording(id).ignore();

        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          final cloudRec = Recording.fromJson(change.doc.data()!);
          final existing = localMap[id];

          final merged = cloudRec.copyWith(
            // Preserve device-local path — cloud carries fileName + backupUrl
            // so any device can re-resolve it if needed
            filePath: existing?.filePath?.isNotEmpty == true
                ? existing!.filePath
                : cloudRec.filePath,
            // Preserve locally-generated waveform data
            waveformData: existing?.waveformData ?? cloudRec.waveformData,
          );

          localMap[id] = merged;

          // Write the merged record to Hive asynchronously (offline cache)
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
      // 1. Persist locally — this must always succeed regardless of connectivity
      await _storageService.saveRecording(recording);
      // 2. Optimistic UI update so the card appears immediately
      await _loadFromHive();
      // 3. Push to Firestore fire-and-forget — if offline this will silently
      //    fail (CloudSyncService swallows the error) and the Firestore
      //    offline cache will retry automatically when connectivity returns.
      //    We do NOT await this so the recording screen can pop immediately.
      _cloudSyncService.syncRecordingToCloud(recording).catchError((e) {
        debugPrint('⚠️ stopRecording: Firestore sync deferred (offline?): $e');
      });
    }
  }

  /// Downloads the audio file for [recording] from Firebase Storage to local
  /// storage, then updates the recording's [filePath] in Hive and state so
  /// playback works immediately.
  ///
  /// Returns the local file path on success, or null if download failed.
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
        final updated = recording.copyWith(filePath: localPath);
        await _storageService.updateRecording(updated);
        // Update in-memory state so the card reflects the new path immediately
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

    // Optimistic removal from state
    state = state.where((r) => r.id != id).toList();

    await _audioService.deleteRecording(recording.filePath);
    await _storageService.deleteRecording(id);

    if (recording.isBackedUp) {
      await _firebaseStorageService.deleteRecording(id);
    }
    // Deleting from Firestore triggers the stream's `removed` event on all
    // other devices, which removes the recording from their state too.
    await _cloudSyncService.deleteRecordingFromCloud(id);
  }

  /// Updates a recording locally and pushes the change to Firestore.
  ///
  /// The optimistic local update ensures the UI responds instantly on this
  /// device. The Firestore write propagates the change to all other devices
  /// via the [_onFirestoreSnapshot] stream handler.
  Future<void> updateRecording(Recording recording) async {
    // 1. Update Hive
    await _storageService.updateRecording(recording);

    // 2. Optimistic state update — Firestore echo will be idempotent
    state = _sortRecordings(
      state.map((r) => r.id == recording.id ? recording : r),
    );

    // 3. Push to Firestore (triggers stream on all devices)
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

  /// Forces a re-read from Hive. Useful after audio file restoration so the
  /// correct local [filePath] is reflected in state before the next Firestore
  /// stream event.
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

  /// Processes all pending backup jobs from the sync queue.
  ///
  /// Called automatically when connectivity is restored (see [main.dart]).
  /// [onJobComplete] fires after each successfully synced recording so the UI
  /// can show a per-item notification.

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

    // You might need to change this if Claude replaced _loadRecordings()
    // with a stream subscription, but keeping it won't hurt.
    // await _loadRecordings();
  }

  // ─── Cloud restore  (first login) ────────────────────────────

  Future<void> restoreFromCloud({bool autoDownloadAudio = false}) async {
    final cloudRecordings = await _cloudSyncService.restoreFromCloud(
      storageService: _firebaseStorageService,
      localStorageService: _storageService,
      autoDownloadAudio: autoDownloadAudio,
    );

    if (cloudRecordings.isEmpty) return;

    // Merge cloud into current in-memory state (cloud wins on conflict)
    final merged = <String, Recording>{
      for (final r in state) r.id: r,
      for (final r in cloudRecordings) r.id: r,
    };

    state = _sortRecordings(merged.values);
  }
}

// ─── Providers ─────────────────────────────────────────────────────────────────

/// The recording provider watches [authStateProvider] so that a new
/// [RecordingNotifier] is created each time the user signs in or out.
///
/// On sign-in:  new notifier created with [userId] set → subscribes to
///              Firestore stream → real-time multi-device sync begins.
/// On sign-out: old notifier disposed → [_firestoreSub] cancelled
///              (no ongoing Firestore reads) → new notifier created with
///              [userId] == null → Hive-only mode.
final recordingProvider =
StateNotifierProvider<RecordingNotifier, List<Recording>>((ref) {
  // Watch auth state — provider rebuilds (and notifier is recreated)
  // whenever the user signs in or out.
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.uid; // null while loading or signed out

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

// ─── Backup progress ───────────────────────────────────────────────────────────

/// Tracks per-recording backup progress (0.0–1.0) and status.
/// null = idle, -1.0 = error.
final backupProgressProvider =
StateProvider.family<double?, String>((ref, recordingId) => null);
