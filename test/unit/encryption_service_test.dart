import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_memo/services/encryption_service.dart';

void main() {
  group('EncryptionService Tests', () {
    test('Encrypt and decrypt text returns original string', () {
      const originalText = "Hello, this is a secret memo!";
      final encrypted = EncryptionService.encrypt(originalText);
      
      expect(encrypted, isNot(equals(originalText)));
      expect(encrypted, isNotEmpty);
      
      final decrypted = EncryptionService.decrypt(encrypted);
      expect(decrypted, originalText);
    });

    test('Decrypting invalid or old data handles errors gracefully', () {
      const plainText = "Already plain text";
      // This might return the placeholder I added earlier or the raw text
      // based on the implementation logic for error handling.
      final result = EncryptionService.decrypt(plainText);
      expect(result, isNotNull);
    });

    test('Encrypt and decrypt bytes returns original data', () {
      final originalBytes = Uint8List.fromList([1, 2, 3, 4, 5, 100, 200, 255]);
      final encrypted = EncryptionService.encryptBytes(originalBytes);
      
      expect(encrypted, isNot(equals(originalBytes)));
      
      final decrypted = EncryptionService.decryptBytes(encrypted);
      expect(decrypted, equals(originalBytes));
    });

    test('Encryption is deterministic with same key/IV', () {
      const text = "Consistent Encryption";
      final encrypted1 = EncryptionService.encrypt(text);
      final encrypted2 = EncryptionService.encrypt(text);
      
      expect(encrypted1, encrypted2);
    });
  });
}
