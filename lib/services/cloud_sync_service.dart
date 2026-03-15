// lib/services/cloud_sync_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vocal_memo/services/encryption%20_service.dart';
import '../models/recording.dart';
import '../models/recording_settings.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'firebase_storage_service.dart';
import 'storage_service.dart';

class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;
  final ConnectivityService _connectivity;

  CloudSyncService(this._authService, this._connectivity);

  String? get _userId => _authService.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────
  // RECORDING METADATA  (Firestore)
  // ─────────────────────────────────────────────────────────────

  Future<void> syncRecordingToCloud(Recording recording) async {
    if (_userId == null) return;
    if (!_connectivity.isOnline) {
      debugPrint('⏭️ Skipping Firestore sync (offline): ${recording.id}');
      return;
    }
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('recordings')
          .doc(recording.id)
          .set(recording.toJson());
    } on SocketException {
      debugPrint('⚠️ Firestore sync skipped (network lost): ${recording.id}');
    } catch (e) {
      debugPrint('Error syncing recording: $e');
    }
  }

  Future<List<Recording>> getRecordingsFromCloud() async {
    if (_userId == null) return [];
    if (!_connectivity.isOnline) {
      debugPrint('⏭️ Skipping cloud fetch (offline)');
      return [];
    }
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('recordings')
          .get();
      return snapshot.docs
          .map((doc) => Recording.fromJson(doc.data()))
          .toList();
    } on SocketException {
      debugPrint('⚠️ Cloud fetch skipped (network lost)');
      return [];
    } catch (e) {
      debugPrint('Error fetching recordings: $e');
      return [];
    }
  }

  Future<void> deleteRecordingFromCloud(String recordingId) async {
    if (_userId == null) return;
    if (!_connectivity.isOnline) {
      debugPrint('⏭️ Skipping cloud delete (offline): $recordingId');
      return;
    }
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('recordings')
          .doc(recordingId)
          .delete();
    } on SocketException {
      debugPrint('⚠️ Cloud delete skipped (network lost): $recordingId');
    } catch (e) {
      debugPrint('Error deleting recording: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SETTINGS  (Firestore)
  // ─────────────────────────────────────────────────────────────

  Future<void> syncSettingsToCloud(RecordingSettings settings) async {
    if (_userId == null) return;
    if (!_connectivity.isOnline) {
      debugPrint('⏭️ Skipping settings sync (offline)');
      return;
    }
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
    } on SocketException {
      debugPrint('⚠️ Settings sync skipped (network lost)');
    } catch (e) {
      debugPrint('Error syncing settings: $e');
    }
  }

  Future<RecordingSettings?> getSettingsFromCloud() async {
    if (_userId == null) return null;
    if (!_connectivity.isOnline) return null;
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
  // BULK SYNC
  // ─────────────────────────────────────────────────────────────

  Future<void> syncAllToCloud({
    required List<Recording> recordings,
    required RecordingSettings settings,
  }) async {
    if (_userId == null) return;
    if (!_connectivity.isOnline) {
      debugPrint('⏭️ Bulk sync deferred (offline)');
      return;
    }
    try {
      await syncSettingsToCloud(settings);
      final batch = _firestore.batch();
      final recordingsRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('recordings');
      for (final recording in recordings) {
        // encrypt transcript before syncing
        if (recording.transcript != null) {
          recording.transcript = EncryptionService.encrypt(recording.transcript!);
        }
        batch.set(recordingsRef.doc(recording.id), recording.toJson());
      }
      await batch.commit();
    } on SocketException {
      debugPrint('⚠️ Bulk sync interrupted (network lost)');
    } catch (e) {
      debugPrint('Error syncing all data: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // RESTORE FROM CLOUD  (fresh install flow)
  // ─────────────────────────────────────────────────────────────

  /// Called after login on a fresh install (or when local Hive is empty).
  ///
  /// Returns an empty list gracefully when offline — the caller should
  /// retry this once connectivity is restored.
  Future<List<Recording>> restoreFromCloud({
    required FirebaseStorageService storageService,
    required StorageService localStorageService,
    void Function(int current, int total)? onProgress,
  }) async {
    if (_userId == null) return [];

    if (!_connectivity.isOnline) {
      debugPrint('⏭️ Cloud restore deferred (offline)');
      return [];
    }

    final cloudRecordings = await getRecordingsFromCloud();
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

        if (!audioAvailable && cloudRecording.isBackedUp) {
          debugPrint('📥 Restoring audio for ${cloudRecording.id} from cloud…');
          final downloadedPath = await storageService.downloadRecording(
            cloudRecording.backupUrl!,
            cloudRecording.id,
            cloudRecording.fileName,
          );
          audioAvailable = downloadedPath != null;
        }

        final updatedRecording = cloudRecording.copyWith(
          filePath: resolvedPath,
        );

        await localStorageService.saveRecording(updatedRecording);
        restored.add(updatedRecording);

        debugPrint(
            '✅ Restored ${cloudRecording.id} (audio available: $audioAvailable)');
      } on OfflineException {
        debugPrint(
            '⚠️ Audio download for ${cloudRecording.id} deferred (went offline mid-restore)');
        await localStorageService.saveRecording(cloudRecording);
        restored.add(cloudRecording);
      } catch (e) {
        debugPrint('❌ Error restoring recording ${cloudRecording.id}: $e');
        await localStorageService.saveRecording(cloudRecording);
        restored.add(cloudRecording);
      }
    }

    debugPrint('🎉 Cloud restore complete: ${restored.length} recordings');
    return restored;
  }
}