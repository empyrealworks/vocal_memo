import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_memo/models/recording.dart';

void main() {
  group('Recording Model Tests', () {
    final now = DateTime.now();
    final recording = Recording(
      id: 'test-id',
      fileName: 'test.m4a',
      title: 'Test Recording',
      filePath: '/path/to/test.m4a',
      createdAt: now,
      duration: const Duration(seconds: 65),
      isFavorite: true,
      isPinned: false,
      numChannels: 1,
    );

    test('Recording displayTitle returns title if provided', () {
      expect(recording.displayTitle, 'Test Recording');
    });

    test('Recording displayTitle returns formatted date if title is null', () {
      final noTitleRecording = Recording(
        id: 'test-id',
        fileName: 'test.m4a',
        filePath: '/path/to/test.m4a',
        createdAt: DateTime(2026, 3, 10, 14, 30),
        duration: const Duration(seconds: 10),
      );
      expect(noTitleRecording.displayTitle, contains('Mar 10'));
    });

    test('Recording formattedDuration handles minutes and seconds correctly', () {
      expect(recording.formattedDuration, '01:05');
    });

    test('Recording serialization (toJson/fromJson)', () {
      final json = recording.toJson();
      final fromJson = Recording.fromJson(json);

      expect(fromJson.id, recording.id);
      expect(fromJson.title, recording.title);
      expect(fromJson.duration, recording.duration);
      expect(fromJson.isFavorite, recording.isFavorite);
      expect(fromJson.numChannels, recording.numChannels);
    });

    test('Recording copyWith works as expected', () {
      final updated = recording.copyWith(title: 'New Title', isPinned: true);
      
      expect(updated.title, 'New Title');
      expect(updated.isPinned, true);
      expect(updated.id, recording.id); // preserved
      expect(updated.isFavorite, recording.isFavorite); // preserved
    });
  });
}
