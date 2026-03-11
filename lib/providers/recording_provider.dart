// lib/providers/recording_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/recording.dart';
import '../models/recording_settings.dart';
import '../services/audio_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/storage_service.dart';
import 'auth_provider.dart';

// ─── Service providers ─────────────────────────────────────────────────────────

final audioServiceProvider = Provider((ref) => AudioService());
final storageServiceProvider = Provider((ref) => StorageService());

// ─── Recording state notifier ──────────────────────────────────────────────────

class RecordingNotifier extends StateNotifier<List<Recording>> {
  final AudioService _audioService;
  final StorageService _storageService;
  final CloudSyncService _cloudSyncService;
  final FirebaseStorageService _firebaseStorageService;

  bool _isRecording = false;

  RecordingNotifier(
      this._audioService,
      this._storageService,
      this._cloudSyncService,
      this._firebaseStorageService,
      ) : super([]) {
    _loadRecordings();
  }

  bool get isRecording => _isRecording;

  Future<void> _loadRecordings() async {
    state = await _storageService.getAllRecordings();
  }

  /// Sorts a flat list of recordings: pinned first (newest→oldest),
  /// then unpinned (newest→oldest). Mirrors [StorageService.getAllRecordings].
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
      await _storageService.saveRecording(recording);
      await _loadRecordings();
    }
  }

  Future<void> pauseRecording() async => _audioService.pauseRecording();
  Future<void> resumeRecording() async => _audioService.resumeRecording();

  /// Stops the audio engine and discards the file — nothing is saved locally
  /// or to the cloud. Used when the user taps "Discard" on the exit dialog.
  Future<void> discardRecording() async {
    await _audioService.discardRecording();
    _isRecording = false;
  }

  Future<void> deleteRecording(String id) async {
    final recording = state.firstWhere((r) => r.id == id);
    await _audioService.deleteRecording(recording.filePath);
    await _storageService.deleteRecording(id);
    // Also clean up Firebase Storage if this recording was backed up
    if (recording.isBackedUp) {
      await _firebaseStorageService.deleteRecording(id);
    }
    await _cloudSyncService.deleteRecordingFromCloud(id);
    await _loadRecordings();
  }

  Future<void> updateRecording(Recording recording) async {
    await _storageService.updateRecording(recording);
    await _cloudSyncService.syncRecordingToCloud(recording);
    await _loadRecordings();
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

  Future<void> refreshRecordings() async => _loadRecordings();

  // ─── Cloud backup ─────────────────────────────────────────────

  /// Encrypts the audio file for [recording] and uploads it to Firebase
  /// Storage, then saves the download URL back to both Hive and Firestore.
  ///
  /// Returns the download URL on success, or null on failure.
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
      await _storageService.updateRecording(updated);
      await _cloudSyncService.syncRecordingToCloud(updated);
      await _loadRecordings();
    }

    return downloadUrl;
  }

  // ─── Cloud restore  (called on login / fresh install) ─────────

  /// Restores recordings from Firestore + Firebase Storage after login.
  ///
  /// Strategy:
  ///   1. Fetch recording documents from Firestore via [CloudSyncService].
  ///      The service resolves cross-device file paths, downloads + decrypts
  ///      any missing backed-up audio, and persists everything to Hive.
  ///   2. Build a merged map keyed by recording ID:
  ///      - Start with the current in-memory state (recordings the user made
  ///        before signing in on this device).
  ///      - Overlay the cloud recordings — cloud wins on conflict because it
  ///        carries the corrected [filePath] and [backupUrl].
  ///   3. Sort and push directly into state — no extra Hive read required.
  Future<void> restoreFromCloud() async {
    final cloudRecordings = await _cloudSyncService.restoreFromCloud(
      storageService: _firebaseStorageService,
      localStorageService: _storageService,
    );

    if (cloudRecordings.isEmpty) return;

    // Merge: local recordings first, then cloud recordings overlay by ID.
    // Using a LinkedHashMap preserves insertion order before sorting.
    final merged = <String, Recording>{
      for (final r in state) r.id: r,           // existing local recordings
      for (final r in cloudRecordings) r.id: r, // cloud overwrites on conflict
    };

    state = _sortRecordings(merged.values);
  }
}

// ─── Providers ─────────────────────────────────────────────────────────────────

final recordingProvider =
StateNotifierProvider<RecordingNotifier, List<Recording>>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  final cloudSyncService = ref.watch(cloudSyncServiceProvider);
  final firebaseStorageService = ref.watch(firebaseStorageServiceProvider);
  return RecordingNotifier(
    audioService,
    storageService,
    cloudSyncService,
    firebaseStorageService,
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

// ─── Backup state per recording ────────────────────────────────────────────────

/// Tracks per-recording backup progress (0.0–1.0) and status.
/// Null means idle, -1.0 means error.
final backupProgressProvider =
StateProvider.family<double?, String>((ref, recordingId) => null);