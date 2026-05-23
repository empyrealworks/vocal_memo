import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_memo/services/encryption_service.dart';

void main() {
  group('EncryptionService Tests', () {
    final encryptionService = EncryptionService();
    test('Encrypt and decrypt text returns original string', () {
      const originalText = "Hello, this is a secret memo!";
      final encrypted = encryptionService.encrypt(originalText);
      
      expect(encrypted, isNot(equals(originalText)));
      expect(encrypted, isNotEmpty);
      expect(encrypted.contains(':'), isTrue);
      
      final decrypted = encryptionService.decrypt(encrypted);
      expect(decrypted, originalText);
    });

    test('Decrypting invalid or old data handles errors gracefully', () {
      const plainText = "Already plain text";
      // This returns the input string if decryption fails or format is wrong
      final result = encryptionService.decrypt(plainText);
      expect(result, equals(plainText));
    });

    test('Encrypt and decrypt bytes returns original data', () {
      final originalBytes = Uint8List.fromList([1, 2, 3, 4, 5, 100, 200, 255]);
      final encrypted = encryptionService.encryptBytes(originalBytes);
      
      expect(encrypted, isNot(equals(originalBytes)));
      expect(encrypted.length, greaterThan(16)); // 16 bytes IV + data
      
      final decrypted = encryptionService.decryptBytes(encrypted);
      expect(decrypted, equals(originalBytes));
    });

    test('Encryption is non-deterministic (different IVs) but decrypts to same value', () {
      const text = "Consistent Encryption";
      final encrypted1 = encryptionService.encrypt(text);
      final encrypted2 = encryptionService.encrypt(text);
      
      // They should be different because of random IV
      expect(encrypted1, isNot(equals(encrypted2)));
      
      // But both should decrypt correctly
      expect(encryptionService.decrypt(encrypted1), equals(text));
      expect(encryptionService.decrypt(encrypted2), equals(text));
    });
  });
}
