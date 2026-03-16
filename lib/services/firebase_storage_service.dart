// lib/services/firebase_storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'encryption _service.dart';

/// Thrown when an upload or download is attempted while the device is offline.
class OfflineException implements Exception {
  final String message;
  const OfflineException([this.message = 'No internet connection.']);
  @override
  String toString() => message;
}

/// Thrown when a transfer is interrupted mid-way by a lost connection.
class TransferInterruptedException implements Exception {
  final String message;
  const TransferInterruptedException(
      [this.message = 'Transfer interrupted. It will resume when you\'re back online.']);
  @override
  String toString() => message;
}

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService;
  final ConnectivityService _connectivity;

  /// Active upload tasks keyed by [recordingId].
  /// Stored so callers can cancel in-flight transfers if needed.
  final Map<String, UploadTask> _activeTasks = {};

  FirebaseStorageService(this._authService, this._connectivity);

  String? get _userId => _authService.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────
  // UPLOAD  (encrypt → upload → return download URL)
  // ─────────────────────────────────────────────────────────────

  /// Encrypts the audio file and uploads it to Firebase Storage.
  ///
  /// Throws [OfflineException] immediately if the device is offline.
  /// Throws [TransferInterruptedException] if the connection drops mid-transfer.
  /// Returns the download URL on success, or throws on any other failure.
  Future<String?> uploadRecording(
      String localPath,
      String recordingId, {
        void Function(double progress)? onProgress,
      }) async {
    if (_userId == null) return null;

    // ── Pre-flight connectivity check ─────────────────────────
    if (!await _connectivity.checkNow()) {
      throw const OfflineException(
          'You\'re offline. The backup will start automatically once you reconnect.');
    }

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

      debugPrint('☁️ Uploading encrypted audio for $recordingId…');
      final uploadTask = ref.putFile(encryptedTempFile);
      _activeTasks[recordingId] = uploadTask;

      // Monitor progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress =
        snapshot.totalBytes > 0
            ? snapshot.bytesTransferred / snapshot.totalBytes
            : 0.0;
        onProgress?.call(progress);
      });

      await uploadTask;
      _activeTasks.remove(recordingId);

      final downloadUrl = await ref.getDownloadURL();
      debugPrint('✅ Upload complete: $recordingId');
      return downloadUrl;
    } on FirebaseException catch (e) {
      _activeTasks.remove(recordingId);
      // Firebase cancellation or network interruption
      if (e.code == 'canceled' || e.code == 'unknown') {
        throw const TransferInterruptedException();
      }
      debugPrint('❌ Firebase upload error [${e.code}]: ${e.message}');
      throw TransferInterruptedException(
          'Upload failed. It will retry when you\'re back online.');
    } on SocketException {
      _activeTasks.remove(recordingId);
      throw const TransferInterruptedException();
    } catch (e) {
      _activeTasks.remove(recordingId);
      debugPrint('❌ Unexpected upload error: $e');
      rethrow;
    } finally {
      // Always clean up the temp encrypted file
      try {
        if (encryptedTempFile != null && await encryptedTempFile.exists()) {
          await encryptedTempFile.delete();
        }
      } catch (_) {}
    }
  }

  /// Cancels an in-flight upload for [recordingId] if one exists.
  Future<void> cancelUpload(String recordingId) async {
    final task = _activeTasks.remove(recordingId);
    if (task != null) {
      await task.cancel();
      debugPrint('🚫 Upload cancelled for $recordingId');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DOWNLOAD  (download → decrypt → save locally)
  // ─────────────────────────────────────────────────────────────

  /// Downloads the encrypted audio from Firebase Storage, decrypts it, and
  /// saves the plain audio file locally.
  ///
  /// Throws [OfflineException] when offline.
  /// Throws [TransferInterruptedException] on mid-transfer disconnection.
  /// Returns the resolved local file path, or null on non-network failure.
  Future<String?> downloadRecording(
      String downloadUrl,
      String recordingId,
      String fileName,
      ) async {
    if (_userId == null) return null;

    // ── Pre-flight connectivity check ─────────────────────────
    if (!await _connectivity.checkNow()) {
      throw const OfflineException(
          'You\'re offline. This recording will download automatically once you reconnect.');
    }

    File? encryptedTempFile;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/recordings');

      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final finalLocalPath = '${recordingsDir.path}/$fileName';
      final finalFile = File(finalLocalPath);

      // Skip download if file already exists and is non-empty
      if (await finalFile.exists() && await finalFile.length() > 0) {
        debugPrint('✅ Audio already exists locally: $finalLocalPath');
        return finalLocalPath;
      }

      // 1. Download encrypted bytes to a temp file
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/${recordingId}_enc.tmp';
      encryptedTempFile = File(tempPath);

      debugPrint('📥 Downloading encrypted audio for $recordingId…');
      final ref = _storage.refFromURL(downloadUrl);
      await ref.writeToFile(encryptedTempFile);

      // 2. Read encrypted bytes and decrypt
      final encryptedBytes = await encryptedTempFile.readAsBytes();
      final decryptedBytes = EncryptionService.decryptBytes(encryptedBytes);

      // 3. Write decrypted audio to the final path
      await finalFile.writeAsBytes(decryptedBytes);
      debugPrint('✅ Download & decrypt complete: $finalLocalPath');
      return finalLocalPath;
    } on FirebaseException catch (e) {
      if (e.code == 'canceled' || e.code == 'unknown') {
        throw const TransferInterruptedException(
            'Download interrupted. It will retry when you\'re back online.');
      }
      debugPrint('❌ Firebase download error [${e.code}]: ${e.message}');
      return null;
    } on SocketException {
      throw const TransferInterruptedException(
          'Download interrupted. It will retry when you\'re back online.');
    } catch (e) {
      debugPrint('❌ Unexpected download error: $e');
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
    if (await File(storedFilePath).exists()) return storedFilePath;

    final dir = await getApplicationDocumentsDirectory();
    final rebuilt = '${dir.path}/recordings/$fileName';
    debugPrint('🔄 Path resolved: $storedFilePath → $rebuilt');
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
    } on SocketException {
      // Deletion will be retried on next launch — not catastrophic
      debugPrint('⚠️ Could not delete from cloud (offline): $recordingId');
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