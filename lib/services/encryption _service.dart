// lib/services/encryption_service.dart
import 'package:encrypt/encrypt.dart';
import '../env/env.dart'; // Use your secure Env class

class EncryptionService {
  // Use a 32-character key for AES-256
  static final _key = Key.fromUtf8(Env.encryptionKey.padRight(32).substring(0, 32));
  // Use a fixed IV for simplicity, or store a unique IV per recording in Hive
  static final _iv = IV.fromLength(16);
  static final _encrypter = Encrypter(AES(_key));

  static String encrypt(String text) {
    if (text.isEmpty) return text;
    return _encrypter.encrypt(text, iv: _iv).base64;
  }

  static String decrypt(String encryptedBase64) {
    if (encryptedBase64.isEmpty) return encryptedBase64;
    try {
      return _encrypter.decrypt64(encryptedBase64, iv: _iv);
    } catch (e) {
      // If decryption fails (e.g., old unencrypted data), return original
      return encryptedBase64;
    }
  }
}