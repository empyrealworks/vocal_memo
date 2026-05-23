// lib/screens/live_recording_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:vocal_memo/models/recording_settings.dart';
import '../providers/settings_provider.dart';
import '../services/recording_notification_service.dart';
import '../theme/app_theme.dart';
import '../providers/recording_provider.dart';

class LiveRecordingScreen extends ConsumerStatefulWidget {
  const LiveRecordingScreen({super.key});

  @override
  ConsumerState<LiveRecordingScreen> createState() =>
      _LiveRecordingScreenState();
}

class _LiveRecordingScreenState extends ConsumerState<LiveRecordingScreen>
    with WidgetsBindingObserver {
  late Stopwatch _stopwatch;
  bool _isRecording    = false;
  bool _isPaused       = false;
  bool _isSaving       = false; // true while we're writing + uploading
  Duration _recordingTime = Duration.zero;

  StreamSubscription<Amplitude>? _amplitudeSub;
  final List<double> _amplitudes = [];
  static const int _maxAmplitudes = 60;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    WidgetsBinding.instance.addObserver(this);

    // Register the callback that receives messages from the task isolate.
    // Must mirror removeTaskDataCallback in dispose().
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);

    // Request notification permission early so the dialog never appears
    // while the microphone is already open.
    RecordingNotificationService.requestPermissions();
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    WidgetsBinding.instance.removeObserver(this);
    _stopwatch.stop();
    _amplitudeSub?.cancel();
    super.dispose();
  }

  // ─── Lifecycle observer ───────────────────────────────────────
  // Refresh displayed time when the user returns from the background so
  // the UI immediately shows the up-to-date elapsed time.

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isRecording && !_isPaused) {
      setState(() => _recordingTime = _stopwatch.elapsed);
    }
  }

  // ─── Task-data callback (messages from notification buttons) ──

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final type = (data)['type'] as String?;

    switch (type) {
      case 'notif_pause_pressed':
      // Notification Pause button → pause the mic and sync UI.
        if (_isRecording && !_isPaused && !_isSaving) {
          _pauseRecordingInternal(notifyTask: false);
        }

      case 'notif_resume_pressed':
      // Notification Resume button → resume the mic and sync UI.
        if (_isRecording && _isPaused && !_isSaving) {
          _resumeRecordingInternal(notifyTask: false);
        }

      case 'notif_stop_pressed':
      // Notification "Stop & Save" button → save recording.
        if (_isRecording && !_isSaving) {
          _stopRecording();
        }
    }
  }

  // ─── Exit guard ───────────────────────────────────────────────

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
      return false;
    }
    await _discardRecording();
    return false;
  }

  // ─── Recording lifecycle ──────────────────────────────────────

  Future<void> _startRecording(RecordingSettings settings) async {
    // Start the foreground service FIRST — on Android this is what keeps
    // the process alive (and the mic open) when the app is backgrounded.
    await RecordingNotificationService.start();

    await ref.read(recordingProvider.notifier).startRecording(settings);

    _amplitudeSub =
        ref.read(audioServiceProvider).onAmplitudeChanged.listen((amp) {
          if (mounted) {
            setState(() {
              _amplitudes.add(amp.current);
              if (_amplitudes.length > _maxAmplitudes) _amplitudes.removeAt(0);
            });
          }
        });

    _stopwatch.start();
    if (mounted) {
      setState(() {
        _isRecording = true;
        _isPaused    = false;
      });
    }
    _tickTimer();
  }

  void _tickTimer() {
    if (!_isRecording || _isPaused) return;
    if (mounted) setState(() => _recordingTime = _stopwatch.elapsed);
    Future.delayed(const Duration(milliseconds: 100), _tickTimer);
  }

  // ── Pause / resume (internal — avoids double-notifying the task) ─

  void _pauseRecordingInternal({required bool notifyTask}) async {
    await ref.read(recordingProvider.notifier).pauseRecording();
    _stopwatch.stop();
    _amplitudeSub?.pause();
    if (notifyTask) RecordingNotificationService.notifyPaused();
    if (mounted) setState(() => _isPaused = true);
  }

  void _resumeRecordingInternal({required bool notifyTask}) async {
    await ref.read(recordingProvider.notifier).resumeRecording();
    _stopwatch.start();
    _amplitudeSub?.resume();
    if (notifyTask) RecordingNotificationService.notifyResumed();
    if (mounted) setState(() => _isPaused = false);
    _tickTimer();
  }

  // ── Public-facing pause / resume (from UI buttons) ────────────

  Future<void> _pauseRecording()  async => _pauseRecordingInternal(notifyTask: true);
  Future<void> _resumeRecording() async => _resumeRecordingInternal(notifyTask: true);

  // ── Stop (save) ───────────────────────────────────────────────

  Future<void> _stopRecording() async {
    if (_isSaving) return; // guard against double-tap / double-call
    if (mounted) setState(() => _isSaving = true);

    _stopwatch.stop();
    _amplitudeSub?.cancel();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused    = false;
      });
    }

    // Save the recording (AudioService writes + extracts waveform, then Hive).
    await ref.read(recordingProvider.notifier).stopRecording();

    // Update the notification to "Saved ✓" for 2 s then dismiss it.
    await RecordingNotificationService.showSavedThenStop();

    if (mounted) Navigator.pop(context);
  }

  // ── Discard ───────────────────────────────────────────────────

  Future<void> _discardRecording() async {
    _stopwatch.stop();
    _amplitudeSub?.cancel();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused    = false;
      });
    }
    await ref.read(recordingProvider.notifier).discardRecording();
    await RecordingNotificationService.stopImmediately();
    if (mounted) Navigator.pop(context);
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final bool isStereo =
        settings.stereoRecording && settings.device == 'Default Microphone';

    return PopScope(
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
            onPressed: () async {
              final canLeave = await _onWillPop();
              if (canLeave && mounted) Navigator.of(context).pop();
            },
          ),
          title: _isSaving
              ? const Text('Saving…')
              : (_isRecording
              ? const Text('Recording...')
              : const Text('New Recording')),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Waveform ────────────────────────────────────
                      Container(
                        width: double.infinity,
                        height: 160,
                        margin:
                        const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: AppTheme.teal.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: _isRecording
                              ? CustomPaint(
                            painter: RealtimeWaveformPainter(
                              amplitudes: _amplitudes,
                              color: AppTheme.teal,
                              isPaused: _isPaused,
                            ),
                            size: const Size(double.infinity, 100),
                          )
                              : Icon(
                            Icons.mic_none_rounded,
                            size: 64,
                            color:
                            AppTheme.teal.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Elapsed time ─────────────────────────────────
                      Text(
                        _formatDuration(_recordingTime),
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(
                          color: AppTheme.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Status text ──────────────────────────────────
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _isSaving
                              ? 'Saving your recording…'
                              : (_isRecording
                              ? (_isPaused
                              ? 'Recording paused'
                              : 'Recording in progress...')
                              : 'Tap the button below to start recording'),
                          textAlign: TextAlign.center,
                          style:
                          Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),

                      if (isStereo && _isRecording)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Stereo Mode Active',
                            style: TextStyle(
                              color: AppTheme.teal,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                      // ── Background hint ──────────────────────────────
                      if (_isRecording && !_isSaving)
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 16, left: 24, right: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 14,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withValues(alpha: 0.55),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Recording continues in the background',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Controls ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _isSaving
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.teal,
                    ),
                  )
                      : _isRecording
                      ? Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
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
                      : SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FloatingActionButton.extended(
                      heroTag: 'start',
                      onPressed: () =>
                          _startRecording(settings),
                      backgroundColor: AppTheme.orange,
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('Start Recording'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(duration.inHours)}:'
        '${dd(duration.inMinutes.remainder(60))}:'
        '${dd(duration.inSeconds.remainder(60))}';
  }
}

enum _ExitChoice { stopAndSave, discard, keepRecording }

// ─── Waveform painter ─────────────────────────────────────────────────────────

class RealtimeWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;
  final bool isPaused;

  const RealtimeWaveformPainter({
    required this.amplitudes,
    required this.color,
    required this.isPaused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final paint = Paint()
      ..color = isPaused ? Colors.grey : color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    const spacing = 6.0;
    const barWidth = 3.0;
    final maxBars = (size.width / (barWidth + spacing)).floor();
    final bars = amplitudes.length > maxBars
        ? amplitudes.sublist(amplitudes.length - maxBars)
        : amplitudes;

    for (int i = 0; i < bars.length; i++) {
      final x = i * (barWidth + spacing);
      final normalized = ((bars[i] + 60) / 60).clamp(0.05, 1.0);
      final h = normalized * size.height;
      canvas.drawLine(
        Offset(x, centerY - h / 2),
        Offset(x, centerY + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RealtimeWaveformPainter old) => true;
}