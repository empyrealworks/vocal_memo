// GENERATED CODE - DO NOT MODIFY BY HAND
// Updated manually to add HiveField(9) enableBeeps.
// Run `flutter pub run build_runner build` to regenerate if the model changes again.

part of 'recording_settings.dart';

class RecordingSettingsAdapter extends TypeAdapter<RecordingSettings> {
  @override
  final int typeId = 0;

  @override
  RecordingSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecordingSettings(
      // Fields 0-8 are unchanged — safe to read from old boxes.
      autoGainControl:
      fields[0] == null ? true : fields[0] as bool,
      noiseSuppression:
      fields[1] == null ? true : fields[1] as bool,
      echoCancellation:
      fields[2] == null ? true : fields[2] as bool,
      device:
      fields[3] == null ? 'Default Microphone' : fields[3] as String,
      bitRate:
      fields[4] == null ? 128000 : fields[4] as int,
      sampleRate:
      fields[5] == null ? 16000 : fields[5] as int,
      audioFormat:
      fields[6] == null ? 'm4a' : fields[6] as String,
      showWaveform:
      fields[7] == null ? true : fields[7] as bool,
      themeMode:
      fields[8] == null ? 'System' : fields[8] as String,
      // Field 9 is new — old boxes won't have it, so default to true.
      enableBeeps:
      fields[9] == null ? true : fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RecordingSettings obj) {
    writer
      ..writeByte(10) // total number of fields
      ..writeByte(0)
      ..write(obj.autoGainControl)
      ..writeByte(1)
      ..write(obj.noiseSuppression)
      ..writeByte(2)
      ..write(obj.echoCancellation)
      ..writeByte(3)
      ..write(obj.device)
      ..writeByte(4)
      ..write(obj.bitRate)
      ..writeByte(5)
      ..write(obj.sampleRate)
      ..writeByte(6)
      ..write(obj.audioFormat)
      ..writeByte(7)
      ..write(obj.showWaveform)
      ..writeByte(8)
      ..write(obj.themeMode)
      ..writeByte(9)
      ..write(obj.enableBeeps);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is RecordingSettingsAdapter &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
}