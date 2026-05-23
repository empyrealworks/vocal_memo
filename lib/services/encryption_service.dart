// lib/services/encryption_service.dart
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' hide Key;
import '../env/env.dart';

class EncryptionService {
  final Encrypter _encrypter;

  EncryptionService([String? key])
      : _encrypter = Encrypter(
          AES(Key.fromUtf8((key ?? Env.encryptionKey).padRight(32).substring(0, 32))),
        );

  // ─── Text (transcript) ───────────────────────────────────────

  String encrypt(String text) {
    if (text.isEmpty) return text;

    // 1. Generate a random IV for THIS specific message
    final iv = IV.fromSecureRandom(16);

    // 2. Encrypt using that random IV
    final encrypted = _encrypter.encrypt(text, iv: iv);

    // 3. Combine IV and Encrypted data (Base64) so we can retrieve the IV later
    // We use a colon or just concatenate the bytes.
    return "${iv.base64}:${encrypted.base64}";
  }

  String decrypt(String encryptedBase64) {
    if (encryptedBase64.isEmpty) return encryptedBase64;
    try {
      // 1. Split the string to get the IV and the Data
      final parts = encryptedBase64.split(':');
      if (parts.length != 2) return encryptedBase64;

      final iv = IV.fromBase64(parts[0]);
      final encryptedData = parts[1];

      // 2. Decrypt using the IV extracted from the string
      return _encrypter.decrypt64(encryptedData, iv: iv);
    } catch (e) {
      return encryptedBase64;
    }
  }

  // ─── Binary (audio file bytes) ───────────────────────────────

  Uint8List encryptBytes(Uint8List bytes) {
    if (bytes.isEmpty) return bytes;

    // 1. Generate a random IV for THIS specific file
    final iv = IV.fromSecureRandom(16);
    try {
      final encrypted = _encrypter.encryptBytes(bytes, iv: iv);

      // 2. Prepend IV (16 bytes) to the encrypted payload
      final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
      combined.setRange(0, iv.bytes.length, iv.bytes);
      combined.setRange(iv.bytes.length, combined.length, encrypted.bytes);

      return combined;
    } catch (e) {
      if (kDebugMode) print('❌ Encryption error (bytes): $e');
      return bytes;
    }
  }

  Uint8List decryptBytes(Uint8List combinedBytes) {
    if (combinedBytes.isEmpty) return combinedBytes;
    try {
      // 1. Minimum length check (must have at least 16 bytes for IV)
      if (combinedBytes.length < 16) {
        throw Exception('Decryption failed: Data too short to contain IV.');
      }

      // 2. Extract the first 16 bytes as the IV
      final ivBytes = combinedBytes.sublist(0, 16);
      final iv = IV(ivBytes);

      // 3. Extract the rest as encrypted data
      final encryptedData = combinedBytes.sublist(16);
      final encrypted = Encrypted(encryptedData);

      // 4. Decrypt using the extracted IV
      final decryptedList = _encrypter.decryptBytes(encrypted, iv: iv);
      return Uint8List.fromList(decryptedList);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Decryption error (bytes): $e. The audio file might be corrupted or the encryption key changed.');
      }
      // Rethrow with a more descriptive message for the Storage service
      throw Exception('Decryption failed: Invalid key or corrupted data.');
    }
  }
}