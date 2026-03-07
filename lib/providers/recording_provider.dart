// lib/providers/recording_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/recording.dart';
import '../models/recording_settings.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';

// Service providers
final audioServiceProvider = Provider((ref) => AudioService());
final storageServiceProvider = Provider((ref) => StorageService());

// Recording state notifier
class RecordingNotifier extends StateNotifier<List<Recording>> {
  final AudioService _audioService;
  final StorageService _storageService;
  bool _isRecording = false;

  RecordingNotifier(this._audioService, this._storageService,) : super([]) {
    _loadRecordings();
  }

  bool get isRecording => _isRecording;

  Future<void> _loadRecordings() async {
    state = await _storageService.getAllRecordings();
  }

  Future<void> startRecording(RecordingSettings settings) async {
    await _audioService.startRecording(settings);
    _isRecording = true;
  }

  Future<void> stopRecording() async {
    final recording = await _audioService.stopRecording();
    _isRecording = false;

    if (recording != null) {
      await _storageService.saveRecording(recording);
      await _loadRecordings();
    }
  }

  Future<void> pauseRecording() async {
    await _audioService.pauseRecording();
  }

  Future<void> resumeRecording() async {
    await _audioService.resumeRecording();
  }

  Future<void> deleteRecording(String id) async {
    final recording = state.firstWhere((r) => r.id == id);
    await _audioService.deleteRecording(recording.filePath);
    await _storageService.deleteRecording(id);
    await _loadRecordings();
  }

  Future<void> updateRecording(Recording recording) async {
    await _storageService.updateRecording(recording);
    await _loadRecordings();
  }

  Future<void> toggleFavorite(String id) async {
    final recording = state.firstWhere((r) => r.id == id);
    await updateRecording(recording.copyWith(isFavorite: !recording.isFavorite));
  }

  Future<void> togglePin(String id) async {
    final recording = state.firstWhere((r) => r.id == id);
    await updateRecording(recording.copyWith(isPinned: !recording.isPinned));
  }

  Future<void> refreshRecordings() async {
    await _loadRecordings();
  }
}

// Providers
final recordingProvider = StateNotifierProvider<RecordingNotifier, List<Recording>>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  return RecordingNotifier(audioService, storageService);
});

final isRecordingProvider = Provider<bool>((ref) {
  return ref.watch(recordingProvider.notifier).isRecording;
});

final pinnedRecordingsProvider = FutureProvider<List<Recording>>((ref) async {
  final recordings = ref.watch(recordingProvider);
  return recordings.where((r) => r.isPinned).toList();
});

final favoriteRecordingsProvider = FutureProvider<List<Recording>>((ref) async {
  final recordings = ref.watch(recordingProvider);
  return recordings.where((r) => r.isFavorite).toList();
});