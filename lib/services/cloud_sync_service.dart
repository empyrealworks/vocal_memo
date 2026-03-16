// lib/services/cloud_sync_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vocal_memo/services/encryption%20_service.dart';
import '../models/recording.dart';
import '../models/recording_settings.dart';
import 'auth_service.dart';
import 'firebase_storage_service.dart';
import 'storage_service.dart';

class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;

  CloudSyncService(this._authService);

  String? get _userId => _authService.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _recordingsRef {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('recordings');
  }

  // ─────────────────────────────────────────────────────────────
  // REAL-TIME STREAM  (Firestore → all devices)
  // ─────────────────────────────────────────────────────────────

  /// Returns a live Firestore snapshot stream for the user's recordings
  /// collection.
  ///
  /// **Firestore billing for this stream:**
  ///   - Session start: 1 read per document currently in the collection.
  ///   - Each subsequent event: 1 read per *changed* document only —
  ///     unchanged documents do not incur reads.
  ///   - The underlying connection is a persistent WebSocket; there is
  ///     no polling overhead.
  ///
  /// **Documents intentionally exclude:**
  ///   - `waveformData` — see [Recording.toCloudJson] for rationale.
  ///   - `filePath`     — device-specific; resolved locally on each device.
  ///
  /// For unregistered users ([_userId] == null) the stream is empty and
  /// no Firestore connection is opened.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecordingsSnapshot() {
    final ref = _recordingsRef;
    if (ref == null) return const Stream.empty();
    return ref.snapshots();
  }

  // ─────────────────────────────────────────────────────────────
  // WRITE — RECORDING METADATA  (Firestore)
  // ─────────────────────────────────────────────────────────────

  Future<void> syncRecordingToCloud(Recording recording) async {
    if (_userId == null) return;
    try {
      await _recordingsRef!.doc(recording.id).set(recording.toCloudJson());
    } catch (e) {
      debugPrint('Error syncing recording: $e');
    }
  }

  Future<void> deleteRecordingFromCloud(String recordingId) async {
    if (_userId == null) return;
    try {
      await _recordingsRef!.doc(recordingId).delete();
    } catch (e) {
      debugPrint('Error deleting recording: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SETTINGS  (Firestore)
  // ─────────────────────────────────────────────────────────────

  Future<void> syncSettingsToCloud(RecordingSettings settings) async {
    if (_userId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('preferences')
          .set({
        'autoGainControl': settings.autoGainControl,
        'noiseSuppression': settings.noiseSuppression,
        'echoCancellation': settings.echoCancellation,
        'device': settings.device,
        'bitRate': settings.bitRate,
        'sampleRate': settings.sampleRate,
        'audioFormat': settings.audioFormat,
        'showWaveform': settings.showWaveform,
        'themeMode': settings.themeMode,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error syncing settings: $e');
    }
  }

  Future<RecordingSettings?> getSettingsFromCloud() async {
    if (_userId == null) return null;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('preferences')
          .get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return RecordingSettings(
        autoGainControl: data['autoGainControl'] ?? true,
        noiseSuppression: data['noiseSuppression'] ?? true,
        echoCancellation: data['echoCancellation'] ?? true,
        device: data['device'] ?? 'Default Microphone',
        bitRate: data['bitRate'] ?? 128000,
        sampleRate: data['sampleRate'] ?? 16000,
        audioFormat: data['audioFormat'] ?? 'm4a',
        showWaveform: data['showWaveform'] ?? true,
        themeMode: data['themeMode'] ?? 'System',
      );
    } catch (e) {
      debugPrint('Error fetching settings: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BULK SYNC  (initial upload after login)
  // ─────────────────────────────────────────────────────────────

  Future<void> syncAllToCloud({
    required List<Recording> recordings,
    required RecordingSettings settings,
  }) async {
    if (_userId == null) return;
    try {
      await syncSettingsToCloud(settings);
      final batch = _firestore.batch();
      final ref = _recordingsRef!;
      for (final recording in recordings) {
        final json = recording.toCloudJson();
        if (recording.transcript != null) {
          json['transcript'] = EncryptionService.encrypt(recording.transcript!);
        }
        batch.set(ref.doc(recording.id), json);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error syncing all data: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RESTORE FROM CLOUD  (fresh install / first login)
  // ─────────────────────────────────────────────────────────────

  /// One-time restore called after the first login on a device.
  ///
  /// The real-time stream ([watchRecordingsSnapshot]) handles all ongoing
  /// metadata sync after this point. This method's sole purpose is to
  /// download missing audio files and resolve device-local [filePath]s
  /// into Hive — metadata is left to the stream.
  ///
  /// [autoDownloadAudio] mirrors the user's Settings toggle. When false,
  /// audio files are *not* downloaded here — the user downloads them
  /// manually from the recording card instead.
  Future<List<Recording>> restoreFromCloud({
    required FirebaseStorageService storageService,
    required StorageService localStorageService,
    bool autoDownloadAudio = false,
    void Function(int current, int total)? onProgress,
  }) async {
    if (_userId == null) return [];

    List<Recording> cloudRecordings;
    try {
      final snapshot = await _recordingsRef!.get();
      cloudRecordings =
          snapshot.docs.map((doc) => Recording.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error fetching recordings for restore: $e');
      return [];
    }

    if (cloudRecordings.isEmpty) return [];

    final restored = <Recording>[];
    int index = 0;

    for (final cloudRecording in cloudRecordings) {
      index++;
      onProgress?.call(index, cloudRecordings.length);

      try {
        final resolvedPath = await FirebaseStorageService.resolveLocalPath(
          cloudRecording.filePath,
          cloudRecording.fileName,
        );

        bool audioAvailable = await File(resolvedPath).exists();

        if (!audioAvailable && cloudRecording.isBackedUp && autoDownloadAudio) {
          debugPrint('📥 Restoring audio for ${cloudRecording.id}…');
          final downloadedPath = await storageService.downloadRecording(
            cloudRecording.backupUrl!,
            cloudRecording.id,
            cloudRecording.fileName,
          );
          audioAvailable = downloadedPath != null;
        } else if (!audioAvailable && cloudRecording.isBackedUp && !autoDownloadAudio) {
          debugPrint('⏭️ Skipping audio download for ${cloudRecording.id} (auto-download off)');
        }

        final updatedRecording = cloudRecording.copyWith(filePath: resolvedPath);
        await localStorageService.saveRecording(updatedRecording);
        restored.add(updatedRecording);

        debugPrint(
            '✅ Restored ${cloudRecording.id} (audio: $audioAvailable)');
      } catch (e) {
        debugPrint('❌ Error restoring ${cloudRecording.id}: $e');
        await localStorageService.saveRecording(cloudRecording);
        restored.add(cloudRecording);
      }
    }

    debugPrint('🎉 Cloud restore complete: ${restored.length} recordings');
    return restored;
  }

  // Legacy one-shot fetch (still used by cloudRestoreProvider)
  Future<List<Recording>> getRecordingsFromCloud() async {
    if (_userId == null) return [];
    try {
      final snapshot = await _recordingsRef!.get();
      return snapshot.docs
          .map((doc) => Recording.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching recordings: $e');
      return [];
    }
  }
}