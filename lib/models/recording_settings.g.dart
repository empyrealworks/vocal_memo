// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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
      autoGainControl: fields[0] as bool,
      noiseSuppression: fields[1] as bool,
      echoCancellation: fields[2] as bool,
      device: fields[3] as String,
      bitRate: fields[4] as int,
      sampleRate: fields[5] as int,
      audioFormat: fields[6] as String,
      showWaveform: fields[7] as bool,
      themeMode: fields[8] as String,
      enableBeeps: fields[9] as bool,
      autoDownloadAudio: fields[10] as bool,
      stereoRecording: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RecordingSettings obj) {
    writer
      ..writeByte(12)
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
      ..write(obj.enableBeeps)
      ..writeByte(10)
      ..write(obj.autoDownloadAudio)
      ..writeByte(11)
      ..write(obj.stereoRecording);
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
