// lib/services/audio_service.dart
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:io';
import '../models/recording.dart';
import '../models/recording_settings.dart';

/// Service for recording audio with proper beep handling
///
/// Ensures beeps don't bleed into recordings by:
/// 1. Playing start beep
/// 2. Waiting for beep to finish
/// 3. Starting recording
/// 4. Stopping recording
/// 5. Playing stop beep
class AudioService {
  final _audioRecorder = AudioRecorder();
  final _beepPlayer = AudioPlayer();

  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Duration _accumulatedDuration = Duration.zero;
  DateTime? _pauseStartTime;
  bool _isPaused = false;

  Future<bool> get isRecording => _audioRecorder.isRecording();

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final hasPermission = await _audioRecorder.hasPermission();
    return hasPermission;
  }

  /// Play a short beep sound
  ///
  /// [isStart] - true for start beep, false for stop beep
  /// Returns after the beep has finished playing
  Future<void> _playBeep(bool isStart) async {
    try {
      // Generate beep programmatically instead of loading from assets
      // This ensures the app works even without bundled sound files

      // For start beep: higher pitch (800Hz)
      // For stop beep: lower pitch (400Hz)

      // Note: Since we can't easily generate audio programmatically in Flutter,
      // we'll use a short delay instead to simulate the beep gap
      // In production, you should add actual beep sound files to assets/sounds/

      // If you have beep files:
      await _beepPlayer.play(AssetSource(isStart ? 'sounds/start_beep.mp3' : 'sounds/stop_beep.mp3'));
      await _beepPlayer.onPlayerComplete.first;

      // For now, just add a small delay to ensure clean recording start/stop
      await Future.delayed(const Duration(milliseconds: 300));

    } catch (e) {
      if (kDebugMode) {
        print('Error playing beep: $e');
      }
      // Continue anyway - beeps are nice to have but not critical
    }
  }

  /// Start recording with proper beep handling
  ///
  /// Flow:
  /// 1. Check permissions
  /// 2. Play start beep
  /// 3. Wait for beep to finish
  /// 4. Start recording
  Future<Recording?> startRecording(RecordingSettings settings) async {
    try {
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final fileName = '${const Uuid().v4()}.${settings.audioFormat}';
      _currentRecordingPath = '${recordingsDir.path}/$fileName';

      // Enable wakelock to keep recording active when screen is off
      await WakelockPlus.enable();
      if (kDebugMode) {
        print('🔒 Wakelock enabled - screen can turn off without stopping recording');
      }

      // IMPORTANT: Play start beep BEFORE starting recording
      if (kDebugMode) {
        print('🔊 Playing start beep...');
      }
      await _playBeep(true);
      if (kDebugMode) {
        print('✅ Start beep finished, beginning recording...');
      }

      _recordingStartTime = DateTime.now();
      _accumulatedDuration = Duration.zero;
      _isPaused = false;

      // Now start recording - beep won't be captured
      await _audioRecorder.start(
        RecordConfig(
          encoder: _getEncoderFromFormat(settings.audioFormat),
          sampleRate: settings.sampleRate,
          bitRate: settings.bitRate,
          autoGain: settings.autoGainControl,
          noiseSuppress: settings.noiseSuppression,
          echoCancel: settings.echoCancellation,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      if (kDebugMode) {
        print('🎙️ Recording started at: $_currentRecordingPath');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting recording: $e');
      }
      // Disable wakelock if recording failed to start
      await WakelockPlus.disable();
      return null;
    }
  }

  AudioEncoder _getEncoderFromFormat(String format) {
    switch (format) {
      case 'wav':
        return AudioEncoder.wav;
      case 'aac':
        return AudioEncoder.aacLc;
      case 'm4a':
        return AudioEncoder.aacLc;
      case 'flac':
        return AudioEncoder.flac;
      default:
        return AudioEncoder.aacLc;
    }
  }

  /// Stop recording with proper beep handling
  ///
  /// Flow:
  /// 1. Stop recording
  /// 2. Play stop beep
  /// 3. Return recording object
  Future<Recording?> stopRecording() async {
    try {
      if (kDebugMode) {
        print('⏹️ Stopping recording...');
      }

      // IMPORTANT: Stop recording FIRST
      final path = await _audioRecorder.stop();

      // Disable wakelock now that recording is stopped
      await WakelockPlus.disable();
      if (kDebugMode) {
        print('🔒 Wakelock disabled - recording stopped - screen can sleep normally');
      }

      if (path == null || _currentRecordingPath == null) {
        return null;
      }

      // Calculate total duration
      if (!_isPaused && _recordingStartTime != null) {
        _accumulatedDuration += DateTime.now().difference(_recordingStartTime!);
      }

      if (kDebugMode) {
        print('✅ Recording stopped, playing stop beep...');
      }

      // NOW play stop beep - won't be in the recording
      await _playBeep(false);

      final file = File(path);
      final recording = Recording(
        id: const Uuid().v4(),
        fileName: file.path.split('/').last,
        filePath: file.path,
        createdAt: DateTime.now().subtract(_accumulatedDuration),
        duration: _accumulatedDuration,
      );

      // Reset state
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _pauseStartTime = null;
      _accumulatedDuration = Duration.zero;
      _isPaused = false;

      if (kDebugMode) {
        print('📝 Recording saved: ${recording.id}');
      }
      return recording;
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping recording: $e');
      }
      // Make sure wakelock is disabled even if there's an error
      await WakelockPlus.disable();
      return null;
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    try {
      await _audioRecorder.pause();

      if (!_isPaused && _recordingStartTime != null) {
        _accumulatedDuration += DateTime.now().difference(_recordingStartTime!);
        _pauseStartTime = DateTime.now();
        _isPaused = true;
      }

      if (kDebugMode) {
        print('⏸️ Recording paused');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error pausing recording: $e');
      }
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    try {
      await _audioRecorder.resume();
      _recordingStartTime = DateTime.now();
      _isPaused = false;

      if (kDebugMode) {
        print('▶️ Recording resumed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error resuming recording: $e');
      }
    }
  }

  /// Stops the recorder and deletes the partial file without saving a Recording.
  /// Used when the user chooses "Discard" on the exit dialog.
  Future<void> discardRecording() async {
    try {
      final path = await _audioRecorder.stop();
      await WakelockPlus.disable();

      // Delete the partial file
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }

      // Reset state
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _pauseStartTime = null;
      _accumulatedDuration = Duration.zero;
      _isPaused = false;

      if (kDebugMode) print('🗑️ Recording discarded');
    } catch (e) {
      await WakelockPlus.disable();
      if (kDebugMode) print('Error discarding recording: $e');
    }
  }

  /// Delete a recording file
  Future<void> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) {
          print('🗑️ Deleted recording: $filePath');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting recording: $e');
      }
    }
  }

  /// Clean up resources
  void dispose() {
    WakelockPlus.disable();
    _audioRecorder.dispose();
    _beepPlayer.dispose();
  }
}