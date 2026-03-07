// lib/services/transcription_service.dart
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

class TranscriptionService {
  final _speechToText = SpeechToText();
  bool _isInitialized = false;
  String _currentTranscript = '';
  bool _isListening = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get currentTranscript => _currentTranscript;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final initialized = await _speechToText.initialize(
        onError: (error) => print('Speech-to-text error: ${error.errorMsg}'),
        onStatus: (status) => print('Speech-to-text status: $status'),
      );
      _isInitialized = initialized;
      return initialized;
    } catch (e) {
      print('Error initializing speech-to-text: $e');
      return false;
    }
  }

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // Transcribe audio file by playing it and listening with microphone
  Future<String?> transcribeFile(String audioFilePath) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final permissionGranted = await requestMicrophonePermission();
      if (!permissionGranted) {
        throw Exception('Microphone permission denied');
      }

      final audioPlayer = AudioPlayer();
      String transcriptResult = '';

      // Set up speech recognition
      await _speechToText.listen(
        onResult: (result) {
          transcriptResult = result.recognizedWords;
          print('Partial transcript: $transcriptResult');
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
        pauseFor: const Duration(seconds: 30),
      );

      // Play the audio file
      await audioPlayer.play(DeviceFileSource(audioFilePath));

      // Wait for audio to finish
      await audioPlayer.onPlayerComplete.first;

      // Stop listening
      await _speechToText.stop();
      await audioPlayer.dispose();

      return transcriptResult.isEmpty ? null : transcriptResult;
    } catch (e) {
      print('Error transcribing file: $e');
      return null;
    }
  }

  Future<void> startLiveTranscription(
    Function(String) onTranscriptUpdate,
    Function(bool) onListeningChanged,
  ) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final permissionGranted = await requestMicrophonePermission();
      if (!permissionGranted) {
        throw Exception('Microphone permission denied');
      }

      _currentTranscript = '';

      await _speechToText.listen(
        onResult: (result) {
          _currentTranscript = result.recognizedWords;
          onTranscriptUpdate(_currentTranscript);
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
        pauseFor: const Duration(seconds: 5),
      );

      _isListening = true;
      onListeningChanged(true);
    } catch (e) {
      print('Error starting live transcription: $e');
      _isListening = false;
      onListeningChanged(false);
    }
  }

  Future<void> stopLiveTranscription(Function(bool) onListeningChanged) async {
    try {
      await _speechToText.stop();
      _isListening = false;
      onListeningChanged(false);
    } catch (e) {
      print('Error stopping live transcription: $e');
    }
  }

  void dispose() {
    _speechToText.cancel();
  }
}
