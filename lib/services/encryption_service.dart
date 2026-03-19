// lib/services/encryption_service.dart
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' hide Key;
import '../env/env.dart';

class EncryptionService {
  // 32-character key → AES-256
  static final _key =
  Key.fromUtf8(Env.encryptionKey.padRight(32).substring(0, 32));

  // ⚠️ IV must be DETERMINISTIC so it survives hot restarts and reinstalls.
  // We derive a fixed 16-byte IV from the first 16 chars of the same key.
  static final _iv =
  IV.fromUtf8(Env.encryptionKey.padRight(16).substring(0, 16));

  static final _encrypter = Encrypter(AES(_key));

  // ─── Text (transcript) ───────────────────────────────────────

  static String encrypt(String text) {
    if (text.isEmpty) return text;
    try {
      return _encrypter.encrypt(text, iv: _iv).base64;
    } catch (e) {
      if (kDebugMode) print('❌ Encryption error (text): $e');
      return text;
    }
  }

  static String decrypt(String encryptedBase64) {
    if (encryptedBase64.isEmpty) return encryptedBase64;
    try {
      return _encrypter.decrypt64(encryptedBase64, iv: _iv);
    } catch (e) {
      // "Invalid or corrupted pad block" usually means the key/IV changed
      if (kDebugMode) {
        print('⚠️ Decryption error: $e. This usually happens if the encryption key in .env or its obfuscation seed changed.');
      }
      // Return a descriptive placeholder instead of raw encrypted garbage
      return '⚠️ [Transcript Corrupted: Unrecoverable due to key change]';
    }
  }

  // ─── Binary (audio file bytes) ───────────────────────────────

  static Uint8List encryptBytes(Uint8List bytes) {
    if (bytes.isEmpty) return bytes;
    try {
      final encrypted = _encrypter.encryptBytes(bytes, iv: _iv);
      return Uint8List.fromList(encrypted.bytes);
    } catch (e) {
      if (kDebugMode) print('❌ Encryption error (bytes): $e');
      return bytes;
    }
  }

  static Uint8List decryptBytes(Uint8List encryptedBytes) {
    if (encryptedBytes.isEmpty) return encryptedBytes;
    try {
      final encrypted = Encrypted(encryptedBytes);
      final decryptedList = _encrypter.decryptBytes(encrypted, iv: _iv);
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