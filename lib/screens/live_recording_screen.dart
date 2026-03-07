// lib/screens/live_recording_screen.dart
import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocal_memo/models/recording_settings.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../providers/recording_provider.dart';
import '../providers/transcription_provider.dart';

class LiveRecordingScreen extends ConsumerStatefulWidget {
  const LiveRecordingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LiveRecordingScreen> createState() =>
      _LiveRecordingScreenState();
}

class _LiveRecordingScreenState extends ConsumerState<LiveRecordingScreen> {
  late Stopwatch _stopwatch;
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  void _startRecording(RecordingSettings settings) async {
    await ref.read(recordingProvider.notifier).startRecording(settings);
    await ref.read(liveTranscriptionProvider.notifier).startListening();
    _stopwatch.start();
    setState(() {
      _isRecording = true;
      _isPaused = false;
    });

    // Update time every 100ms
    Future.delayed(const Duration(milliseconds: 100), _updateTime);
  }

  void _updateTime() {
    if (_isRecording && !_isPaused) {
      setState(() => _recordingTime = _stopwatch.elapsed);
      Future.delayed(const Duration(milliseconds: 100), _updateTime);
    }
  }

  Future<void> _pauseRecording() async {
    await ref.read(recordingProvider.notifier).pauseRecording();
    _stopwatch.stop();

    setState(() {
      _isPaused = true;
    });
  }

  Future<void> _resumeRecording() async {
    await ref.read(recordingProvider.notifier).resumeRecording();

    _stopwatch.start();
    setState(() {
      _isPaused = false;
    });
    _updateTime();
  }

  void _stopRecording() async {
    _stopwatch.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    await ref.read(liveTranscriptionProvider.notifier).stopListening();
    await ref.read(recordingProvider.notifier).stopRecording();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveTranscription = ref.watch(liveTranscriptionProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isRecording
            ? Text('Recording...')
            : const Text('New Recording'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Waveform animation
                Container(
                  width: double.infinity,
                  height: 150,
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _isRecording
                        ? CustomPaint(
                            painter: AnimatedWaveformPainter(
                              color: AppTheme.teal,
                              animationValue:
                                  (_stopwatch.elapsedMilliseconds % 1000) /
                                  1000,
                            ),
                            size: const Size(double.infinity, 150),
                          )
                        : Icon(
                            Icons.mic_none_rounded,
                            size: 64,
                            color: AppTheme.teal.withValues(alpha: 0.3),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Time display
                Text(
                  _formatDuration(_recordingTime),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppTheme.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Transcript preview
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (liveTranscription.isListening && _isRecording)
                          Text(
                            'Live Transcript',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(fontSize: 14),
                          ),
                        if (liveTranscription.transcript.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.lightGray,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                liveTranscription.transcript,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Recording controls
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (_isRecording)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: AppTheme.lightGray,
                        foregroundColor: AppTheme.orange,
                        onPressed: !_isRecording
                            ? null
                            : _isPaused
                            ? _resumeRecording
                            : _pauseRecording,
                        child: IconButton(
                          icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                          onPressed: !_isRecording
                              ? null
                              : _isPaused
                              ? _resumeRecording
                              : _pauseRecording,
                          tooltip: _isPaused ? 'Resume' : 'Pause',
                        ),
                      ),
                      FloatingActionButton(
                        backgroundColor: AppTheme.orange,
                        onPressed: _stopRecording,
                        child: const Icon(Icons.stop_rounded),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FloatingActionButton.extended(
                      onPressed: () => _startRecording(settings),
                      backgroundColor: AppTheme.orange,
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('Start Recording'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }
}

// Animated waveform painter for live recording
class AnimatedWaveformPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  AnimatedWaveformPainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final barWidth = 8.0;
    final spacing = 12.0;

    final totalWidth = 5 * (barWidth + spacing);
    final startX = (size.width - totalWidth) / 2;

    for (int i = 0; i < 5; i++) {
      final x = startX + (i * (barWidth + spacing)) + barWidth / 2;
      final height =
          20 + (40 * (0.5 + 0.5 * Math.sin(animationValue * 6.28 + i)));

      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(AnimatedWaveformPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
