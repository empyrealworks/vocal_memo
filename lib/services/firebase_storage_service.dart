// lib/services/firebase_storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';
import 'encryption _service.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService;

  FirebaseStorageService(this._authService);

  String? get _userId => _authService.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────
  // UPLOAD  (encrypt → upload → return download URL)
  // ─────────────────────────────────────────────────────────────

  /// Encrypts the audio file and uploads it to Firebase Storage.
  /// Returns the download URL on success, or null on failure.
  Future<String?> uploadRecording(
      String localPath,
      String recordingId, {
        void Function(double progress)? onProgress,
      }) async {
    if (_userId == null) return null;

    File? encryptedTempFile;
    try {
      final originalFile = File(localPath);
      if (!await originalFile.exists()) {
        debugPrint('❌ File not found: $localPath');
        return null;
      }

      // 1. Read raw bytes and encrypt
      final rawBytes = await originalFile.readAsBytes();
      final encryptedBytes = EncryptionService.encryptBytes(rawBytes);

      // 2. Write encrypted bytes to a temp file
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/${recordingId}_enc.tmp';
      encryptedTempFile = File(tempPath);
      await encryptedTempFile.writeAsBytes(encryptedBytes);

      // 3. Upload temp file to Firebase Storage
      final fileName = localPath.split('/').last;
      final ref = _storage
          .ref()
          .child('users/$_userId/recordings/$recordingId/$fileName.enc');

      debugPrint('☁️ Uploading encrypted audio to Firebase Storage…');
      final uploadTask = ref.putFile(encryptedTempFile);

      // Monitor progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint(
            '  Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        onProgress?.call(progress);
      });

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('✅ Upload complete: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading file: $e');
      return null;
    } finally {
      // 4. Clean up temp encrypted file
      try {
        if (encryptedTempFile != null && await encryptedTempFile.exists()) {
          await encryptedTempFile.delete();
        }
      } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DOWNLOAD  (download → decrypt → save locally)
  // ─────────────────────────────────────────────────────────────

  /// Downloads the encrypted audio from Firebase Storage, decrypts it, and
  /// saves the plain audio file locally.
  ///
  /// [fileName] is the original audio file name (e.g. "rec_abc123.m4a").
  /// Returns the resolved local file path, or null on failure.
  Future<String?> downloadRecording(
      String downloadUrl,
      String recordingId,
      String fileName,
      ) async {
    if (_userId == null) return null;

    File? encryptedTempFile;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/recordings');

      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final finalLocalPath = '${recordingsDir.path}/$fileName';
      final finalFile = File(finalLocalPath);

      // Skip download if file already exists and is valid
      if (await finalFile.exists() && await finalFile.length() > 0) {
        debugPrint('✅ Audio already exists locally: $finalLocalPath');
        return finalLocalPath;
      }

      // 1. Download encrypted bytes to a temp file
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/${recordingId}_enc.tmp';
      encryptedTempFile = File(tempPath);

      debugPrint('📥 Downloading encrypted audio from Firebase Storage…');
      final ref = _storage.refFromURL(downloadUrl);
      await ref.writeToFile(encryptedTempFile);

      // 2. Read encrypted bytes and decrypt
      final encryptedBytes = await encryptedTempFile.readAsBytes();
      final decryptedBytes = EncryptionService.decryptBytes(encryptedBytes);

      // 3. Write decrypted audio to the final path
      await finalFile.writeAsBytes(decryptedBytes);
      debugPrint('✅ Download & decrypt complete: $finalLocalPath');
      return finalLocalPath;
    } catch (e) {
      debugPrint('❌ Error downloading file: $e');
      return null;
    } finally {
      try {
        if (encryptedTempFile != null && await encryptedTempFile.exists()) {
          await encryptedTempFile.delete();
        }
      } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PATH UTILITIES
  // ─────────────────────────────────────────────────────────────

  /// Returns the correct device-specific local path for a recording file,
  /// regardless of what path was stored on a different device.
  ///
  /// If the stored [filePath] is still valid, it is returned as-is.
  /// Otherwise, the path is rebuilt from [appDocsDir]/recordings/[fileName].
  static Future<String> resolveLocalPath(
      String storedFilePath,
      String fileName,
      ) async {
    // Fast path: file already exists at the stored path
    if (await File(storedFilePath).exists()) return storedFilePath;

    // Rebuild path for this device
    final dir = await getApplicationDocumentsDirectory();
    final rebuilt = '${dir.path}/recordings/$fileName';
    debugPrint(
        '🔄 Path resolved: $storedFilePath → $rebuilt');
    return rebuilt;
  }

  // ─────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────

  /// Deletes all files for a recording from Firebase Storage.
  Future<void> deleteRecording(String recordingId) async {
    if (_userId == null) return;

    try {
      final ref =
      _storage.ref().child('users/$_userId/recordings/$recordingId');
      final listResult = await ref.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
      debugPrint('🗑️ Deleted recording from cloud: $recordingId');
    } catch (e) {
      debugPrint('❌ Error deleting from storage: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // STORAGE USAGE
  // ─────────────────────────────────────────────────────────────

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
      debugPrint('Error getting storage usage: $e');
      return 0;
    }
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}