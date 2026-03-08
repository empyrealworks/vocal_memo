
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/trim_segment.dart';

class AudioEditorService {
  /// Apply multiple trims to an audio file
  /// Keeps only the segments specified in keepSegments
  /// Returns the path to the new trimmed file
  Future<String?> applyMultipleTrims({
    required String inputPath,
    required List<TrimSegment> keepSegments,
  }) async {
    try {
      if (keepSegments.isEmpty) return null;

      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/recordings');

      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // If only one segment, use simple trim
      if (keepSegments.length == 1) {
        return await _simpleTrim(
          inputPath: inputPath,
          startTime: keepSegments[0].start,
          endTime: keepSegments[0].end,
        );
      }

      // Multiple segments - extract and concatenate
      final tempFiles = <String>[];

      // Extract each segment
      for (int i = 0; i < keepSegments.length; i++) {
        final segment = keepSegments[i];
        final tempPath = '${recordingsDir.path}/temp_$i.m4a';

        final startStr = _formatDuration(segment.start);
        final durationStr = _formatDuration(segment.duration);

        final command = '-i "$inputPath" -ss $startStr -t $durationStr -c copy "$tempPath"';
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          tempFiles.add(tempPath);
        } else {
          // Clean up and return null
          for (var file in tempFiles) {
            File(file).deleteSync();
          }
          return null;
        }
      }

      // Create concat file list
      final concatListPath = '${recordingsDir.path}/concat_list.txt';
      final concatContent = tempFiles.map((f) => "file '$f'").join('\n');
      await File(concatListPath).writeAsString(concatContent);

      // Concatenate all segments
      final outputFileName = '${const Uuid().v4()}.m4a';
      final outputPath = '${recordingsDir.path}/$outputFileName';

      final concatCommand = '-f concat -safe 0 -i "$concatListPath" -c copy "$outputPath"';
      final concatSession = await FFmpegKit.execute(concatCommand);
      final concatReturnCode = await concatSession.getReturnCode();

      // Clean up temp files
      for (var file in tempFiles) {
        File(file).deleteSync();
      }
      File(concatListPath).deleteSync();

      if (ReturnCode.isSuccess(concatReturnCode)) {
        if (kDebugMode) {
          print('Multi-trim successful: $outputPath');
        }
        return outputPath;
      } else {
        final output = await concatSession.getOutput();
        if (kDebugMode) {
          print('Concatenation failed: $output');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error applying multiple trims: $e');
      }
      return null;
    }
  }

  /// Simple trim for single segment
  Future<String?> _simpleTrim({
    required String inputPath,
    required Duration startTime,
    required Duration endTime,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/recordings');

      final outputFileName = '${const Uuid().v4()}.m4a';
      final outputPath = '${recordingsDir.path}/$outputFileName';

      final startTimeStr = _formatDuration(startTime);
      final duration = endTime - startTime;
      final durationStr = _formatDuration(duration);

      final command = '-i "$inputPath" -ss $startTimeStr -t $durationStr -c copy "$outputPath"';
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error in simple trim: $e');
      }
      return null;
    }
  }

  /// Detect silence at start and end of audio file
  Future<Map<String, Duration>?> detectSilence(String filePath) async {
    try {
      final command = '-i "$filePath" -af silencedetect=noise=-30dB:d=0.5 -f null -';

      final session = await FFmpegKit.execute(command);
      final output = await session.getOutput();

      if (output == null) return null;

      Duration? silenceStart;
      Duration? silenceEnd;

      final lines = output.split('\n');
      for (var line in lines) {
        if (line.contains('silence_start')) {
          if (silenceStart == null) {
            final match = RegExp(r'silence_start: ([\d.]+)').firstMatch(line);
            if (match != null) {
              final seconds = double.parse(match.group(1)!);
              silenceStart = Duration(milliseconds: (seconds * 1000).toInt());
            }
          }
        }
        if (line.contains('silence_end')) {
          final match = RegExp(r'silence_end: ([\d.]+)').firstMatch(line);
          if (match != null) {
            final seconds = double.parse(match.group(1)!);
            silenceEnd = Duration(milliseconds: (seconds * 1000).toInt());
          }
        }
      }

      return {
        'start': silenceStart ?? Duration.zero,
        'end': silenceEnd ?? Duration.zero,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error detecting silence: $e');
      }
      return null;
    }
  }

  /// Format duration for FFmpeg (HH:MM:SS.mmm)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String threeDigits(int n) => n.toString().padLeft(3, '0');

    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds = threeDigits(duration.inMilliseconds.remainder(1000));

    return '$hours:$minutes:$seconds.$milliseconds';
  }
}