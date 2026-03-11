// lib/services/encryption_service.dart
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import '../env/env.dart';

class EncryptionService {
  // 32-character key → AES-256
  static final _key =
  Key.fromUtf8(Env.encryptionKey.padRight(32).substring(0, 32));

  // ⚠️  IV must be DETERMINISTIC so it survives hot restarts and reinstalls.
  // IV.fromLength(16) generates random bytes on every static initialisation,
  // which changes on every hot-restart and breaks decryption of persisted data.
  // We derive a fixed 16-byte IV from the first 16 chars of the same key.
  static final _iv =
  IV.fromUtf8(Env.encryptionKey.padRight(16).substring(0, 16));

  static final _encrypter = Encrypter(AES(_key));

  // ─── Text (transcript) ───────────────────────────────────────

  static String encrypt(String text) {
    if (text.isEmpty) return text;
    return _encrypter.encrypt(text, iv: _iv).base64;
  }

  static String decrypt(String encryptedBase64) {
    if (encryptedBase64.isEmpty) return encryptedBase64;
    try {
      return _encrypter.decrypt64(encryptedBase64, iv: _iv);
    } catch (_) {
      // Gracefully handle old unencrypted data
      return encryptedBase64;
    }
  }

  // ─── Binary (audio file bytes) ───────────────────────────────

  static Uint8List encryptBytes(Uint8List bytes) {
    final encrypted = _encrypter.encryptBytes(bytes, iv: _iv);
    return Uint8List.fromList(encrypted.bytes);
  }

  static Uint8List decryptBytes(Uint8List encryptedBytes) {
    final encrypted = Encrypted(encryptedBytes);
    final decryptedList = _encrypter.decryptBytes(encrypted, iv: _iv);
    return Uint8List.fromList(decryptedList);
  }
}