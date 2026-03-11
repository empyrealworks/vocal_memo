// lib/services/cloud_sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/recording.dart';
import '../models/recording_settings.dart';
import 'auth_service.dart';

class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;

  CloudSyncService(this._authService);

  String? get _userId => _authService.currentUser?.uid;

  // Sync recordings to cloud
  Future<void> syncRecordingToCloud(Recording recording) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('recordings')
          .doc(recording.id)
          .set(recording.toJson());
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing recording: $e');
      }
    }
  }

  // Sync settings to cloud
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
      if (kDebugMode) {
        print('Error syncing settings: $e');
      }
    }
  }

  // Get recordings from cloud
  Future<List<Recording>> getRecordingsFromCloud() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('recordings')
          .get();

      return snapshot.docs
          .map((doc) => Recording.fromJson(doc.data()))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching recordings: $e');
      }
      return [];
    }
  }

  // Get settings from cloud
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
        device: data['device'] ?? "Default Microphone",
        bitRate: data['bitRate'] ?? 128000,
        sampleRate: data['sampleRate'] ?? 16000,
        audioFormat: data['audioFormat'] ?? "m4a",
        showWaveform: data['showWaveform'] ?? true,
        themeMode: data['themeMode'] ?? "System",
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching settings: $e');
      }
      return null;
    }
  }

  // Delete recording from cloud
  Future<void> deleteRecordingFromCloud(String recordingId) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('recordings')
          .doc(recordingId)
          .delete();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting recording: $e');
      }
    }
  }

  // Sync all local data to cloud on sign in
  Future<void> syncAllToCloud({
    required List<Recording> recordings,
    required RecordingSettings settings,
  }) async {
    if (_userId == null) return;

    try {
      // Sync settings first
      await syncSettingsToCloud(settings);

      // Sync recordings in batches
      final batch = _firestore.batch();
      final recordingsRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('recordings');

      for (final recording in recordings) {

        batch.set(
          recordingsRef.doc(recording.id),
          recording.toJson(),
        );
      }

      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing all data: $e');
      }
    }
  }
}