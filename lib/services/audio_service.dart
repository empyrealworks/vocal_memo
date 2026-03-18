// lib/services/audio_service.dart
//
// audioplayers removed. Beeps are played via a short-lived PlayerController
// after writing the asset bytes to a temp file. This keeps audio_waveforms
// as the single audio dependency for the whole project.

import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/recording.dart';
import '../models/recording_settings.dart';

/// Service for recording audio with optional beep cues.
///
/// Beep flow (when enabled):
///   start beep → mic opens → recording → mic closes → stop beep
///
/// Beeps are played via a temporary PlayerController. The MP3 asset is
/// written to the temp directory once per beep call (the OS caches the
/// write so the second call is negligible).
class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();

  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Duration _accumulatedDuration = Duration.zero;
  DateTime? _pauseStartTime;
  bool _isPaused = false;
  int _currentChannels = 1;

  // Stored at startRecording so stopRecording honours the same setting.
  bool _enableBeeps = true;

  Future<bool> get isRecording => _audioRecorder.isRecording();

  Future<bool> requestMicrophonePermission() async {
    return _audioRecorder.hasPermission();
  }

  /// Requests permissions for Bluetooth / nearby devices on Android 12+.
  Future<bool> requestNearbyDevicesPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.bluetoothConnect.request();
      return status.isGranted;
    }
    return true; // Not required on other platforms for basic listing
  }

  /// Lists available audio input devices (including Bluetooth and wired).
  Future<List<InputDevice>> listInputDevices() async {
    // Attempting to request permission here ensures devices like Bluetooth
    // headsets are visible to the package.
    await requestNearbyDevicesPermission();
    return _audioRecorder.listInputDevices();
  }

  /// Cleans up long, cluttered hardware labels from the `record` package.
  ///
  /// Example mappings:
  /// - "Device (built-in microphone, bottom)" -> "Internal Mic (Bottom)"
  /// - "Device (Bluetooth telephony SCO, ...)" -> "Device (Bluetooth)"
  static String cleanDeviceLabel(String label) {
    if (label == "Default Microphone") return "Default";

    // Check for internal microphones
    if (label.contains('built-in microphone')) {
      final parts = label.split(',');
      if (parts.length > 1) {
        final location = parts.last.replaceAll(')', '').trim();
        return 'Internal Mic (${location[0].toUpperCase()}${location.substring(1)})';
      }
      return 'Internal Mic';
    }

    // Check for Bluetooth devices
    if (label.toLowerCase().contains('bluetooth')) {
      final parenIndex = label.indexOf('(');
      if (parenIndex != -1) {
        final name = label.substring(0, parenIndex).trim();
        return '$name (Bluetooth)';
      }
      return label;
    }

    // Check for FM Tuner
    if (label.toLowerCase().contains('fm tuner')) {
      return 'FM Tuner';
    }

    // For everything else, strip the device model name if it's outside parens
    // and just show what's inside if the outside part is long.
    final parenIndex = label.indexOf('(');
    if (parenIndex > 10) {
      // arbitrary length to catch model names
      final description = label
          .substring(parenIndex)
          .replaceAll('(', '')
          .replaceAll(')', '')
          .trim();
      if (description.isNotEmpty) {
        return description[0].toUpperCase() + description.substring(1);
      }
    }

    return label;
  }

  // ── Amplitude Stream ─────────────────────────────────────────────────────

  Stream<Amplitude> get onAmplitudeChanged =>
      _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100));

  // ── Beep ─────────────────────────────────────────────────────────────────

  /// Plays a beep from [assets/sounds/].
  ///
  /// Writes the asset bytes to [tempDir] and plays via a short-lived
  /// [PlayerController]. The controller is disposed after the tone finishes.
  Future<void> _playBeep(bool isStart) async {
    PlayerController? beepController;

    File? tempFile;

    try {
      final assetKey =
          'assets/sounds/${isStart ? 'start_beep' : 'stop_beep'}.mp3';

      // Load asset bytes from bundle.
      final ByteData byteData = await rootBundle.load(assetKey);
      final Uint8List bytes = byteData.buffer.asUint8List();

      // Write to temp dir (reuses same filename each time — no leaking files).
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/${isStart ? 'start' : 'stop'}_beep.mp3';
      tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);

      // Play with a dedicated controller.
      beepController = PlayerController();
      await beepController.preparePlayer(
        path: tempPath,
        shouldExtractWaveform: false,
      );
      await beepController.startPlayer();

      // Wait for natural completion (with a 3-second safety timeout).
      await beepController.onCompletion.first.timeout(
        const Duration(seconds: 3),
      );

      // Extra gap to ensure no bleed into the recording microphone open.
      await Future.delayed(const Duration(milliseconds: 150));
    } catch (e) {
      if (kDebugMode) print('Beep error (non-fatal): $e');
      // Beeps are optional — recording continues regardless of errors here.
    } finally {
      beepController?.dispose();
      // Temp file is small (<5 KB) and will be overwritten next time.
      // Only delete on errors; keeping it speeds up the next beep.
    }
  }

  // ── Recording ─────────────────────────────────────────────────────────────

  /// Starts a recording session.
  ///
  /// If [settings.enableBeeps] is true the start beep plays and completes
  /// before the microphone opens, so it is never captured in the file.
  Future<Recording?> startRecording(RecordingSettings settings) async {
    try {
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) throw Exception('Microphone permission denied');

      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final fileName = '${const Uuid().v4()}.${settings.audioFormat}';
      _currentRecordingPath = '${recordingsDir.path}/$fileName';

      _enableBeeps = settings.enableBeeps;

      await WakelockPlus.enable();

      if (_enableBeeps) {
        if (kDebugMode) print('🔊 Playing start beep…');
        await _playBeep(true);
        if (kDebugMode) print('✅ Start beep done — opening microphone');
      }

      _recordingStartTime = DateTime.now();
      _accumulatedDuration = Duration.zero;
      _isPaused = false;

      // Handle custom input device selection
      InputDevice? selectedDevice;
      if (settings.device != "Default Microphone") {
        final devices = await listInputDevices();
        try {
          // Find device by ID or Label
          selectedDevice = devices.firstWhere(
            (d) => d.id == settings.device || d.label == settings.device,
          );
        } catch (_) {
          if (kDebugMode) {
            print(
              'Selected device "${settings.device}" not found, using default.',
            );
          }
        }
      }

      // Stereo (2 channels) works best on the "Default" system device where the
      // OS can manage the dual internal mics. Selecting a specific hardware
      // port ID usually results in a mono stream from that specific mic.
      _currentChannels = (settings.stereoRecording && selectedDevice == null)
          ? 2
          : 1;

      if (kDebugMode) {
        print('🎙️ [RecordConfig] AutoGain: ${settings.autoGainControl}');
        print('🎙️ [RecordConfig] NoiseSuppress: ${settings.noiseSuppression}');
        print('🎙️ [RecordConfig] EchoCancel: ${settings.echoCancellation}');
        print('🎙️ [RecordConfig] Channels: $_currentChannels');
        print(
          '🎙️ [RecordConfig] Device: ${selectedDevice?.label ?? "Default"}',
        );
      }

      await _audioRecorder.start(
        RecordConfig(
          encoder: _getEncoderFromFormat(settings.audioFormat),
          sampleRate: settings.sampleRate,
          bitRate: settings.bitRate,
          autoGain: settings.autoGainControl,
          noiseSuppress: settings.noiseSuppression,
          echoCancel: settings.echoCancellation,
          numChannels: _currentChannels,
          device: selectedDevice,
        ),
        path: _currentRecordingPath!,
      );

      if (kDebugMode) print('🎙️ Recording started: $_currentRecordingPath');
      return null;
    } catch (e) {
      if (kDebugMode) print('Error starting recording: $e');
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

  /// Stops the recording and returns the saved [Recording].
  ///
  /// The microphone closes first, then the stop beep plays (if enabled),
  /// so the beep is never captured in the file.
  Future<Recording?> stopRecording() async {
    try {
      if (kDebugMode) print('⏹️ Stopping recording…');

      final path = await _audioRecorder.stop();
      await WakelockPlus.disable();

      if (path == null || _currentRecordingPath == null) return null;

      if (!_isPaused && _recordingStartTime != null) {
        _accumulatedDuration += DateTime.now().difference(_recordingStartTime!);
      }

      if (_enableBeeps) {
        if (kDebugMode) print('🔊 Playing stop beep…');
        await _playBeep(false);
      }

      final file = File(path);
      final recording = Recording(
        id: const Uuid().v4(),
        fileName: file.path.split('/').last,
        filePath: file.path,
        createdAt: DateTime.now().subtract(_accumulatedDuration),
        duration: _accumulatedDuration,
        numChannels: _currentChannels,
      );

      _currentRecordingPath = null;
      _recordingStartTime = null;
      _pauseStartTime = null;
      _accumulatedDuration = Duration.zero;
      _isPaused = false;

      if (kDebugMode) print('📝 Recording saved: ${recording.id}');
      return recording;
    } catch (e) {
      if (kDebugMode) print('Error stopping recording: $e');
      await WakelockPlus.disable();
      return null;
    }
  }

  Future<void> pauseRecording() async {
    try {
      await _audioRecorder.pause();
      if (!_isPaused && _recordingStartTime != null) {
        _accumulatedDuration += DateTime.now().difference(_recordingStartTime!);
        _pauseStartTime = DateTime.now();
        _isPaused = true;
      }
      if (kDebugMode) print('⏸️ Recording paused');
    } catch (e) {
      if (kDebugMode) print('Error pausing: $e');
    }
  }

  Future<void> resumeRecording() async {
    try {
      await _audioRecorder.resume();
      _recordingStartTime = DateTime.now();
      _isPaused = false;
      if (kDebugMode) print('▶️ Recording resumed');
    } catch (e) {
      if (kDebugMode) print('Error resuming: $e');
    }
  }

  Future<void> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (e) {
      if (kDebugMode) print('Error deleting: $e');
    }
  }

  /// Discards the current recording without saving — deletes the partial file.
  Future<void> discardRecording() async {
    try {
      final path = await _audioRecorder.stop();
      await WakelockPlus.disable();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _pauseStartTime = null;
      _accumulatedDuration = Duration.zero;
      _isPaused = false;
      if (kDebugMode) print('🗑️ Recording discarded');
    } catch (e) {
      if (kDebugMode) print('Error discarding: $e');
      await WakelockPlus.disable();
    }
  }

  /// Extracts waveform data for caching.
  Future<List<double>> extractWaveformData(String path) async {
    final controller = PlayerController();
    try {
      // Use the extraction API from the latest documentation snippet
      return await controller.waveformExtraction.extractWaveformData(
        path: path,
        noOfSamples: 100, // Pre-calculate 100 points for the summary waveform
      );
    } catch (e) {
      if (kDebugMode) print('Error extracting waveform: $e');
      return [];
    } finally {
      controller.dispose();
    }
  }

  void dispose() {
    WakelockPlus.disable();
    _audioRecorder.dispose();
  }
}
