import 'package:hive_flutter/hive_flutter.dart';

part 'recording_settings.g.dart';

@HiveType(typeId: 0)
class RecordingSettings extends HiveObject {
  @HiveField(0)
  bool autoGainControl;

  @HiveField(1)
  bool noiseSuppression;

  @HiveField(2)
  bool echoCancellation;

  @HiveField(3)
  String device;

  @HiveField(4)
  int bitRate;

  @HiveField(5)
  int sampleRate;

  @HiveField(6)
  String audioFormat;

  @HiveField(7)
  bool showWaveform;

  @HiveField(8)
  String themeMode;

  // HiveField(9) — added in v1.3.0. Existing boxes missing this field
  // will default to true (beeps on) via the generated adapter.
  @HiveField(9)
  bool enableBeeps;

  RecordingSettings({
    this.autoGainControl = true,
    this.noiseSuppression = true,
    this.echoCancellation = true,
    this.device = "Default Microphone",
    this.bitRate = 128000,
    this.sampleRate = 16000,
    this.audioFormat = "m4a",
    this.showWaveform = true,
    this.themeMode = "System",
    this.enableBeeps = true,
  });

  RecordingSettings copyWith({
    bool? autoGainControl,
    bool? noiseSuppression,
    bool? echoCancellation,
    String? device,
    int? bitRate,
    int? sampleRate,
    String? audioFormat,
    bool? showWaveform,
    String? themeMode,
    bool? enableBeeps,
  }) {
    return RecordingSettings(
      autoGainControl: autoGainControl ?? this.autoGainControl,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      echoCancellation: echoCancellation ?? this.echoCancellation,
      device: device ?? this.device,
      bitRate: bitRate ?? this.bitRate,
      sampleRate: sampleRate ?? this.sampleRate,
      audioFormat: audioFormat ?? this.audioFormat,
      showWaveform: showWaveform ?? this.showWaveform,
      themeMode: themeMode ?? this.themeMode,
      enableBeeps: enableBeeps ?? this.enableBeeps,
    );
  }
}