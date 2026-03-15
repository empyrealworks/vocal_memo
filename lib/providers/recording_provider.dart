// lib/providers/recording_provider.dart
import 'package:flutter/material.dart';
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

// ─── Backup result ─────────────────────────────────────────────────────────────

/// The outcome of a [RecordingNotifier.backupRecording] call.
sealed class BackupResult {}

/// The upload completed successfully. [url] is the Firebase download URL.
class BackupSuccess extends BackupResult {
  final String url;
  BackupSuccess(this.url);
}

/// The device was offline. The job has been queued and will be processed
/// automatically when connectivity is restored.
class BackupQueued extends BackupResult {}

/// The upload failed for a non-network reason.
class BackupFailed extends BackupResult {
  final String message;
  BackupFailed(this.message);
}

// ─── Recording state notifier ──────────────────────────────────────────────────

class RecordingNotifier extends StateNotifier<List<Recording>> {
  final AudioService _audioService;
  final StorageService _storageService;
  final CloudSyncService _cloudSyncService;
  final FirebaseStorageService _firebaseStorageService;
  final ConnectivityService _connectivity;
  final SyncQueueService _syncQueue;

  bool _isRecording = false;

  RecordingNotifier(
      this._audioService,
      this._storageService,
      this._cloudSyncService,
      this._firebaseStorageService,
      this._connectivity,
      this._syncQueue,
      ) : super([]) {
    _loadRecordings();
  }

  bool get isRecording => _isRecording;

  Future<void> _loadRecordings() async {
    state = await _storageService.getAllRecordings();
  }

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

  Future<void> discardRecording() async {
    await _audioService.discardRecording();
    _isRecording = false;
  }

  Future<void> deleteRecording(String id) async {
    final recording = state.firstWhere((r) => r.id == id);
    await _audioService.deleteRecording(recording.filePath);
    await _storageService.deleteRecording(id);
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

  /// Uploads a recording's audio to Firebase Storage.
  ///
  /// Returns a [BackupResult]:
  /// - [BackupSuccess] — upload complete, recording updated locally + in cloud.
  /// - [BackupQueued]  — device is offline; job saved to the sync queue and
  ///                     will be processed automatically when back online.
  /// - [BackupFailed]  — upload failed for a non-network reason.
  Future<BackupResult> backupRecordingWithResult(
      Recording recording, {
        void Function(double progress)? onProgress,
      }) async {
    // ── Offline fast-path ──────────────────────────────────────
    if (!_connectivity.isOnline) {
      await _syncQueue.enqueue(PendingSyncJob(
        recordingId: recording.id,
        filePath: recording.filePath,
        enqueuedAt: DateTime.now(),
      ));
      return BackupQueued();
    }

    try {
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
        return BackupSuccess(downloadUrl);
      }
      return BackupFailed('Upload failed. Please try again.');
    } on OfflineException catch (e) {
      // Connectivity dropped mid-attempt — enqueue for later
      await _syncQueue.enqueue(PendingSyncJob(
        recordingId: recording.id,
        filePath: recording.filePath,
        enqueuedAt: DateTime.now(),
      ));
      debugPrint('⏭️ Backup queued (went offline): ${recording.id} — $e');
      return BackupQueued();
    } on TransferInterruptedException catch (e) {
      await _syncQueue.enqueue(PendingSyncJob(
        recordingId: recording.id,
        filePath: recording.filePath,
        enqueuedAt: DateTime.now(),
      ));
      debugPrint('⏭️ Backup queued (transfer interrupted): ${recording.id} — $e');
      return BackupQueued();
    } catch (e) {
      debugPrint('❌ Backup failed: ${recording.id} — $e');
      return BackupFailed(e.toString());
    }
  }

  /// Legacy wrapper for callers that only care about the download URL.
  /// Returns the URL on success, or null on failure / when queued.
  Future<String?> backupRecording(
      Recording recording, {
        void Function(double progress)? onProgress,
      }) async {
    final result = await backupRecordingWithResult(recording, onProgress: onProgress);
    return result is BackupSuccess ? result.url : null;
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
        // Re-fetch the recording in case it was updated/deleted locally
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
        break; // Stop draining — we're offline again
      } on TransferInterruptedException {
        debugPrint('⚠️ Sync queue: transfer interrupted, stopping drain');
        break;
      } catch (e) {
        debugPrint('❌ Sync queue: error processing ${job.recordingId}: $e');
        // Leave the job in the queue for the next drain attempt
      }
    }

    await _loadRecordings();
  }

  // ─── Cloud restore  (called on login / fresh install) ─────────

  Future<void> restoreFromCloud() async {
    final cloudRecordings = await _cloudSyncService.restoreFromCloud(
      storageService: _firebaseStorageService,
      localStorageService: _storageService,
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
  final audioService = ref.watch(audioServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  final cloudSyncService = ref.watch(cloudSyncServiceProvider);
  final firebaseStorageService = ref.watch(firebaseStorageServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final syncQueue = ref.watch(syncQueueServiceProvider);
  return RecordingNotifier(
    audioService,
    storageService,
    cloudSyncService,
    firebaseStorageService,
    connectivity,
    syncQueue,
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

/// Tracks per-recording backup state.
///
/// Values:
/// - null       → idle
/// - 0.0 – 1.0  → upload progress
/// - -1.0       → error
/// - -2.0       → queued (offline, will sync when back online)
final backupProgressProvider =
StateProvider.family<double?, String>((ref, recordingId) => null);

/// Convenience constant so call sites don't use magic numbers.
const double kBackupQueued = -2.0;
const double kBackupError = -1.0;