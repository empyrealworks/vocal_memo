// lib/screens/live_recording_screen.dart
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocal_memo/models/recording_settings.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../providers/recording_provider.dart';

class LiveRecordingScreen extends ConsumerStatefulWidget {
  const LiveRecordingScreen({super.key});

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

  // ─── Guard ────────────────────────────────────────────────────

  /// Called whenever the user tries to leave (back gesture, X button, etc.).
  /// If recording is in progress, asks whether to stop-and-save or discard.
  /// Returns true when it's safe to pop.
  Future<bool> _onWillPop() async {
    if (!_isRecording) return true;

    final result = await showDialog<_ExitChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_rounded,
                    color: AppTheme.orange, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Recording in progress',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'What would you like to do?',
                style: Theme.of(ctx).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Stop & Save
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('Stop & Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () =>
                      Navigator.of(ctx).pop(_ExitChoice.stopAndSave),
                ),
              ),
              const SizedBox(height: 8),
              // Discard
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Discard'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(_ExitChoice.discard),
                ),
              ),
              const SizedBox(height: 8),
              // Keep recording
              TextButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(_ExitChoice.keepRecording),
                child: Text(
                  'Keep Recording',
                  style: TextStyle(color: Theme.of(ctx).hintColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || result == _ExitChoice.keepRecording) return false;

    if (result == _ExitChoice.stopAndSave) {
      await _stopRecording();
      return false; // _stopRecording already pops
    }

    // Discard: stop the engine silently without saving
    await _discardRecording();
    return false; // we pop manually below
  }

  // ─── Recording lifecycle ─────────────────────────────────────

  void _startRecording(RecordingSettings settings) async {
    await ref.read(recordingProvider.notifier).startRecording(settings);
    _stopwatch.start();
    setState(() {
      _isRecording = true;
      _isPaused = false;
    });
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
    setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    await ref.read(recordingProvider.notifier).resumeRecording();
    _stopwatch.start();
    setState(() => _isPaused = false);
    _updateTime();
  }

  Future<void> _stopRecording() async {
    _stopwatch.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
    await ref.read(recordingProvider.notifier).stopRecording();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _discardRecording() async {
    _stopwatch.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });
    // Stop the audio engine without saving
    await ref.read(recordingProvider.notifier).discardRecording();
    if (mounted) Navigator.pop(context);
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return PopScope(
      // canPop: false makes Flutter call onPopInvokedWithResult before popping
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canLeave = await _onWillPop();
        if (canLeave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            // Route through the same guard as the system back gesture
            onPressed: () async {
              final canLeave = await _onWillPop();
              if (canLeave && mounted) Navigator.of(context).pop();
            },
          ),
          title: _isRecording
              ? const Text('Recording...')
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
                    style:
                    Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _isRecording
                          ? (_isPaused
                          ? 'Recording paused'
                          : 'Recording in progress...')
                          : 'Tap the button below to start recording',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Info hint (only when idle)
                  if (!_isRecording)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.teal.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.teal, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'After recording, use the transcribe button to convert speech to text',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
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

            // Controls
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_isRecording)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FloatingActionButton(
                          heroTag: 'pause_resume',
                          mini: true,
                          backgroundColor: AppTheme.lightGray,
                          foregroundColor: AppTheme.orange,
                          onPressed: _isPaused
                              ? _resumeRecording
                              : _pauseRecording,
                          child: Icon(_isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded),
                        ),
                        FloatingActionButton(
                          heroTag: 'stop',
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
                        heroTag: 'start',
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
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';
  }
}

enum _ExitChoice { stopAndSave, discard, keepRecording }

// ─── Animated waveform painter ────────────────────────────────────────────────

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
    const barWidth = 8.0;
    const spacing = 12.0;
    const barCount = 5;
    const totalWidth = barCount * (barWidth + spacing);
    final startX = (size.width - totalWidth) / 2;

    for (int i = 0; i < barCount; i++) {
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
  bool shouldRepaint(AnimatedWaveformPainter old) =>
      old.animationValue != animationValue;
}