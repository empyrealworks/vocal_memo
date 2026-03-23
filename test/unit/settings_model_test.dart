import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_memo/models/recording_settings.dart';

void main() {
  group('RecordingSettings Model Tests', () {
    test('Default values are set correctly', () {
      final settings = RecordingSettings();
      
      expect(settings.autoGainControl, true);
      expect(settings.noiseSuppression, true);
      expect(settings.echoCancellation, true);
      expect(settings.device, "Default Microphone");
      expect(settings.bitRate, 128000);
      expect(settings.sampleRate, 16000);
      expect(settings.audioFormat, "m4a");
      expect(settings.showWaveform, true);
      expect(settings.themeMode, "System");
      expect(settings.enableBeeps, true);
      expect(settings.autoDownloadAudio, false);
      expect(settings.stereoRecording, false);
    });

    test('copyWith works correctly for all fields', () {
      final settings = RecordingSettings();
      final updated = settings.copyWith(
        autoGainControl: false,
        noiseSuppression: false,
        echoCancellation: false,
        device: "External Mic",
        bitRate: 256000,
        sampleRate: 44100,
        audioFormat: "wav",
        showWaveform: false,
        themeMode: "Dark",
        enableBeeps: false,
        autoDownloadAudio: true,
        stereoRecording: true,
      );

      expect(updated.autoGainControl, false);
      expect(updated.noiseSuppression, false);
      expect(updated.echoCancellation, false);
      expect(updated.device, "External Mic");
      expect(updated.bitRate, 256000);
      expect(updated.sampleRate, 44100);
      expect(updated.audioFormat, "wav");
      expect(updated.showWaveform, false);
      expect(updated.themeMode, "Dark");
      expect(updated.enableBeeps, false);
      expect(updated.autoDownloadAudio, true);
      expect(updated.stereoRecording, true);
    });
  });
}
