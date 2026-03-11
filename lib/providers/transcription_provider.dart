// lib/providers/transcription_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import '../services/encryption _service.dart';
import '../services/gemini_transcription_service.dart';
import '../models/recording.dart';
import 'auth_provider.dart';
import 'recording_provider.dart';

/// Provider for Gemini transcription service
final geminiTranscriptionServiceProvider = Provider<GeminiTranscriptionService>((ref) {
  // Watch the gemini model provider
  final modelName = ref.watch(geminiModelProvider);
  return GeminiTranscriptionService(modelName: modelName);
});

/// State for tracking transcription progress
class TranscriptionState {
  final bool isTranscribing;
  final String? error;
  final double? progress; // 0.0 to 1.0

  const TranscriptionState({
    this.isTranscribing = false,
    this.error,
    this.progress,
  });

  TranscriptionState copyWith({
    bool? isTranscribing,
    String? error,
    double? progress,
  }) {
    return TranscriptionState(
      isTranscribing: isTranscribing ?? this.isTranscribing,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

/// StateNotifier for managing transcription state
class TranscriptionNotifier extends StateNotifier<TranscriptionState> {
  final GeminiTranscriptionService _service;
  final Ref _ref;

  TranscriptionNotifier(this._service, this._ref)
      : super(const TranscriptionState());

  /// Transcribe a recording
  Future<String?> transcribe(Recording recording) async {
    // Don't re-transcribe if already has transcript
    if (recording.transcript != null && recording.transcript!.isNotEmpty) {
      return recording.transcript;
    }

    try {
      // Update state to show transcribing
      state = const TranscriptionState(isTranscribing: true);

      // Get the appropriate model for user's tier
      final authService = _ref.read(authServiceProvider);
      final model = authService.geminiModel;

      if (kDebugMode) {
        print('🎯 Transcribing with model: $model (tier: ${authService.userTier})');
      }
      if (kDebugMode) {
        print('🎙️ Recording: ${recording.id}');
      }

      final transcript = await _service.transcribeAudioFile(
        recording.filePath,
        modelName: model,
      );

      if (transcript != null && transcript.isNotEmpty) {
        // 🔐 ENCRYPT BEFORE SAVING
        final encryptedTranscript = EncryptionService.encrypt(transcript);
        // Update the recording with transcript
        final recordingNotifier = _ref.read(recordingProvider.notifier);
        final updatedRecording = recording.copyWith(
          transcript: encryptedTranscript,
          isTranscribing: false,
        );

        await recordingNotifier.updateRecording(updatedRecording);

        // Sync to cloud if user is authenticated
        if (authService.isAuthenticated) {
          if (kDebugMode) {
            print('☁️ Syncing transcript to cloud...');
          }
          final syncService = _ref.read(cloudSyncServiceProvider);
          await syncService.syncRecordingToCloud(updatedRecording);
        }

        // Update state
        state = const TranscriptionState(isTranscribing: false);

        if (kDebugMode) {
          print('✅ Transcription complete for ${recording.id}');
        }
        return transcript;
      } else {
        throw Exception('Transcription returned empty result');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Transcription failed for ${recording.id}: $e');
      }

      // Update state with error
      state = TranscriptionState(
        isTranscribing: false,
        error: e.toString(),
      );

      // Mark recording as not transcribing
      final recordingNotifier = _ref.read(recordingProvider.notifier);
      await recordingNotifier.updateRecording(
        recording.copyWith(isTranscribing: false),
      );

      rethrow;
    }
  }

  void reset() {
    state = const TranscriptionState();
  }
}

/// Provider for transcription state per recording
final transcriptionNotifierProvider =
StateNotifierProvider.family<TranscriptionNotifier, TranscriptionState, String>(
      (ref, recordingId) {
    final service = ref.watch(geminiTranscriptionServiceProvider);
    return TranscriptionNotifier(service, ref);
  },
);

/// Provider to get transcription status for a recording
final transcriptionStatusProvider = Provider.family<String, String>(
      (ref, recordingId) {
    final state = ref.watch(transcriptionNotifierProvider(recordingId));

    if (state.isTranscribing) {
      return 'Transcribing...';
    } else if (state.error != null) {
      return 'Transcription failed';
    } else {
      return 'Ready to transcribe';
    }
  },
);