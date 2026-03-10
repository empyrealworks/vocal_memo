// lib/services/firebase_storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService;

  FirebaseStorageService(this._authService);

  String? get _userId => _authService.currentUser?.uid;

  /// Upload audio file to Firebase Storage
  /// Returns the download URL
  Future<String?> uploadRecording(String localPath, String recordingId) async {
    if (_userId == null) return null;

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        print('❌ File not found: $localPath');
        return null;
      }

      final fileName = localPath.split('/').last;
      final ref = _storage.ref().child('users/$_userId/recordings/$recordingId/$fileName');

      print('☁️ Uploading to Firebase Storage...');
      final uploadTask = ref.putFile(file);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      await uploadTask;

      final downloadUrl = await ref.getDownloadURL();
      print('✅ Upload complete: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading file: $e');
      return null;
    }
  }

  /// Download audio file from Firebase Storage
  /// Returns the local file path
  Future<String?> downloadRecording(String downloadUrl, String recordingId) async {
    if (_userId == null) return null;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/recordings');

      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Extract filename from URL or use recordingId
      final fileName = downloadUrl.split('/').last.split('?').first;
      final localPath = '${recordingsDir.path}/$fileName';
      final localFile = File(localPath);

      // Skip if already downloaded
      if (await localFile.exists()) {
        print('✅ File already exists locally: $localPath');
        return localPath;
      }

      print('📥 Downloading from Firebase Storage...');
      final ref = _storage.refFromURL(downloadUrl);

      await ref.writeToFile(localFile);

      print('✅ Download complete: $localPath');
      return localPath;
    } catch (e) {
      print('❌ Error downloading file: $e');
      return null;
    }
  }

  /// Delete recording from Firebase Storage
  Future<void> deleteRecording(String recordingId) async {
    if (_userId == null) return;

    try {
      final ref = _storage.ref().child('users/$_userId/recordings/$recordingId');

      // Delete all files in the recording folder
      final listResult = await ref.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }

      print('🗑️ Deleted recording from cloud: $recordingId');
    } catch (e) {
      print('❌ Error deleting from storage: $e');
    }
  }

  /// Get storage usage for user
  Future<int> getStorageUsage() async {
    if (_userId == null) return 0;

    try {
      final ref = _storage.ref().child('users/$_userId/recordings');
      final listResult = await ref.listAll();

      int totalSize = 0;
      for (final item in listResult.items) {
        final metadata = await item.getMetadata();
        totalSize += metadata.size ?? 0;
      }

      return totalSize;
    } catch (e) {
      print('Error getting storage usage: $e');
      return 0;
    }
  }

  /// Format bytes to human-readable format
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}