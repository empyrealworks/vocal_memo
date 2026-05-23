import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocal_memo/models/recording.dart';
import 'package:vocal_memo/providers/recording_provider.dart';
import '../test_utils.dart';

void main() {
  test('RecordingNotifier initial state is empty', () {
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(FakeStorageService()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(recordingProvider), []);
  });

  test('RecordingNotifier loads recordings from Hive on init', () async {
    final fakeStorage = FakeStorageService();
    fakeStorage.recordings = [
      Recording(
        id: '1',
        fileName: 'file.m4a',
        filePath: 'path',
        createdAt: DateTime.now(),
        duration: Duration.zero,
      )
    ];

    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(fakeStorage),
      ],
    );
    addTearDown(container.dispose);

    // Wait for the initialization microtask
    await Future.delayed(Duration.zero);

    expect(container.read(recordingProvider).length, 1);
    expect(container.read(recordingProvider)[0].id, '1');
  });

  test('RecordingNotifier deleteRecording removes from state and storage', () async {
    final fakeStorage = FakeStorageService();
    final rec = Recording(
      id: 'delete-me',
      fileName: 'file.m4a',
      filePath: 'path',
      createdAt: DateTime.now(),
      duration: Duration.zero,
    );
    fakeStorage.recordings = [rec];

    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(fakeStorage),
      ],
    );
    addTearDown(container.dispose);

    await Future.delayed(Duration.zero);
    expect(container.read(recordingProvider).length, 1);

    await container.read(recordingProvider.notifier).deleteRecording('delete-me');

    expect(container.read(recordingProvider).length, 0);
    expect(fakeStorage.recordings.length, 0);
  });
}
