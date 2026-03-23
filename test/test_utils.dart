import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocal_memo/models/recording.dart';
import 'package:vocal_memo/services/audio_service.dart';
import 'package:vocal_memo/services/storage_service.dart';
import 'package:vocal_memo/services/cloud_sync_service.dart';
import 'package:vocal_memo/services/firebase_storage_service.dart';
import 'package:vocal_memo/services/connectivity_service.dart';
import 'package:vocal_memo/services/sync_queue_service.dart';
import 'package:vocal_memo/services/auth_service.dart';

class FakeStorageService extends StorageService {
  List<Recording> recordings = [];
  @override
  Future<List<Recording>> getAllRecordings() async => recordings;
  @override
  Future<void> saveRecording(Recording recording) async => recordings.add(recording);
  @override
  Future<void> updateRecording(Recording recording) async {
    final index = recordings.indexWhere((r) => r.id == recording.id);
    if (index != -1) recordings[index] = recording;
  }
  @override
  Future<void> deleteRecording(String id) async => recordings.removeWhere((r) => r.id == id);
}

class FakeAudioService extends AudioService {}

class FakeCloudSyncService extends CloudSyncService {
  FakeCloudSyncService() : super(FakeAuthService());
}

class FakeAuthService extends AuthService {}

class FakeConnectivityService implements ConnectivityService {
  @override
  bool get isOnline => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);

  @override
  Future<void> init() async {}

  @override
  Future<bool> checkNow() async => true;

  @override
  void dispose() {}
}

class FakeSyncQueueService extends SyncQueueService {
  @override
  List<PendingSyncJob> peekAll() => [];
}

class FakeFirebaseStorageService extends FirebaseStorageService {
  FakeFirebaseStorageService() : super(FakeAuthService(), FakeConnectivityService());
}
