// lib/services/recording_notification_service.dart
//
// Background recording service — flutter_foreground_task ^9.2.1
//
// ──────────────────────────────────────────────────────────────────────────────
// Architecture
// ──────────────────────────────────────────────────────────────────────────────
//
//  ┌─────────────────────────────┐       ┌────────────────────────────────────┐
//  │  Main isolate               │       │  Task isolate (foreground service) │
//  │  LiveRecordingScreen        │       │  RecordingTaskHandler              │
//  │                             │       │                                    │
//  │  • Owns AudioService        │◄──────│  • Owns elapsed timer              │
//  │  • Owns UI state            │       │  • Owns notification state         │
//  │  • Drives save / navigate   │──────►│  • Updates notification every 1 s  │
//  └─────────────────────────────┘       └────────────────────────────────────┘
//
// Main → Task  (sendDataToTask):
//   {'type': 'ui_paused'}   — user paused from the app UI
//   {'type': 'ui_resumed'}  — user resumed from the app UI
//
// Task → Main  (sendDataToMain):
//   {'type': 'notif_pause_pressed'}  — Pause button tapped in notification
//   {'type': 'notif_resume_pressed'} — Resume button tapped in notification
//   {'type': 'notif_stop_pressed'}   — "Stop & Save" tapped in notification
//
// Stop flow (notification-initiated):
//   task sends 'notif_stop_pressed' → main saves audio → main calls
//   showSavedThenStop() → notification shows "Saved ✓" for 2 s → stopService()
//
// Stop flow (UI-initiated):
//   main saves audio → main calls showSavedThenStop()   (same tail)
//
// ──────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// ─── Notification button IDs ───────────────────────────────────────────────────

const _kBtnPause  = 'btn_pause';
const _kBtnResume = 'btn_resume';
const _kBtnStop   = 'btn_stop';

// ─── Foreground-task entry point ───────────────────────────────────────────────

/// Top-level callback — must be a top-level function with this annotation.
@pragma('vm:entry-point')
void recordingForegroundEntryPoint() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

// ─── Task handler (runs in the background isolate) ─────────────────────────────

class RecordingTaskHandler extends TaskHandler {
  Duration _accumulated = Duration.zero;
  DateTime? _segmentStart;
  bool _isPaused   = false;
  bool _isStopping = false; // prevents further updates after stop is requested

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _accumulated  = Duration.zero;
    _segmentStart = DateTime.now();
    _isPaused     = false;
    _isStopping   = false;
    _pushNotification();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_isStopping) return;
    _pushNotification();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Audio lifecycle is owned by AudioService in the main isolate — nothing
    // to clean up here.
  }

  // ── Messages from main isolate ────────────────────────────────

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    final type = (data as Map)['type'] as String?;
    switch (type) {
      case 'ui_paused':
        _applyPause();
      case 'ui_resumed':
        _applyResume();
    }
  }

  // ── Notification button presses ───────────────────────────────

  @override
  void onNotificationButtonPressed(String id) {
    switch (id) {
      case _kBtnPause:
        _applyPause();
        // Tell main isolate so AudioService can pause the mic.
        FlutterForegroundTask.sendDataToMain({'type': 'notif_pause_pressed'});

      case _kBtnResume:
        _applyResume();
        FlutterForegroundTask.sendDataToMain({'type': 'notif_resume_pressed'});

      case _kBtnStop:
        if (_isStopping) return;
        _isStopping = true;
        // Give the user instant visual feedback while the main isolate saves.
        FlutterForegroundTask.updateService(
          notificationTitle: 'Saving recording…',
          notificationText: _formatElapsed(),
          notificationButtons: [],
        );
        FlutterForegroundTask.sendDataToMain({'type': 'notif_stop_pressed'});
    }
  }

  @override
  void onNotificationPressed() {
    // Tapping the notification body brings the app back to the foreground.
    FlutterForegroundTask.launchApp('/');
  }

  // ── Helpers ───────────────────────────────────────────────────

  void _applyPause() {
    if (_isPaused) return;
    if (_segmentStart != null) {
      _accumulated += DateTime.now().difference(_segmentStart!);
      _segmentStart = null;
    }
    _isPaused = true;
    _pushNotification();
  }

  void _applyResume() {
    if (!_isPaused) return;
    _segmentStart = DateTime.now();
    _isPaused = false;
    _pushNotification();
  }

  Duration _elapsed() {
    if (_segmentStart == null) return _accumulated;
    return _accumulated + DateTime.now().difference(_segmentStart!);
  }

  String _formatElapsed() {
    final d = _elapsed();
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(d.inHours)}:${dd(d.inMinutes.remainder(60))}:${dd(d.inSeconds.remainder(60))}';
  }

  void _pushNotification() {
    FlutterForegroundTask.updateService(
      notificationTitle: _isPaused ? '⏸ Recording Paused' : '🔴 Recording',
      notificationText: _formatElapsed(),
      notificationButtons: _isPaused
          ? [
        const NotificationButton(id: _kBtnResume, text: 'Resume'),
        const NotificationButton(id: _kBtnStop,   text: 'Stop & Save'),
      ]
          : [
        const NotificationButton(id: _kBtnPause, text: 'Pause'),
        const NotificationButton(id: _kBtnStop,  text: 'Stop & Save'),
      ],
    );
  }
}

// ─── Public service façade (main isolate) ──────────────────────────────────────

/// Manages the foreground service lifecycle from the main isolate.
///
/// ```dart
/// // Once, before first use (e.g. in LiveRecordingScreen.initState)
/// await RecordingNotificationService.requestPermissions();
///
/// // When recording starts
/// await RecordingNotificationService.start();
///
/// // Sync pause / resume state with the task isolate
/// RecordingNotificationService.notifyPaused();
/// RecordingNotificationService.notifyResumed();
///
/// // After the audio file has been written to disk
/// await RecordingNotificationService.showSavedThenStop();
///
/// // On discard or error
/// await RecordingNotificationService.stopImmediately();
/// ```
class RecordingNotificationService {
  RecordingNotificationService._();

  static bool _initialized = false;

  // ── Init ──────────────────────────────────────────────────────

  static void _ensureInitialized() {
    if (_initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'vocal_memo_recording',
        channelName: 'Vocal Memo Recording',
        channelDescription:
        'Shows recording status and controls while a recording is active.',
        // LOW keeps it silent — no sound or heads-up peeking.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 1-second repeat keeps the elapsed-time display accurate.
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        // Wake lock prevents the CPU from sleeping mid-recording.
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    _initialized = true;
  }

  // ── Permissions ───────────────────────────────────────────────

  /// Requests the POST_NOTIFICATIONS permission (Android 13+).
  ///
  /// Call once early — e.g. in [LiveRecordingScreen.initState] — so the
  /// system dialog never appears mid-recording.
  static Future<void> requestPermissions() async {
    final status = await FlutterForegroundTask.checkNotificationPermission();
    if (status != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────

  /// Starts the foreground service and shows the recording notification.
  static Future<void> start() async {
    _ensureInitialized();

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: '🔴 Recording',
        notificationText: '00:00:00',
        notificationButtons: [
          const NotificationButton(id: _kBtnPause, text: 'Pause'),
          const NotificationButton(id: _kBtnStop,  text: 'Stop & Save'),
        ],
        callback: recordingForegroundEntryPoint,
      );
    }

    if (kDebugMode) print('🔔 RecordingNotificationService: started');
  }

  /// Syncs the task isolate's timer when the UI pauses recording.
  static void notifyPaused() =>
      FlutterForegroundTask.sendDataToTask({'type': 'ui_paused'});

  /// Syncs the task isolate's timer when the UI resumes recording.
  static void notifyResumed() =>
      FlutterForegroundTask.sendDataToTask({'type': 'ui_resumed'});

  /// Shows "Recording Saved ✓" for 2 seconds then dismisses the service.
  ///
  /// Call this after the audio file has been successfully written to disk.
  static Future<void> showSavedThenStop() async {
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Recording Saved ✓',
        notificationText: 'Your recording is ready.',
        notificationButtons: [],
      );
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      await FlutterForegroundTask.stopService();
      if (kDebugMode) print('🔕 RecordingNotificationService: stopped');
    }
  }

  /// Dismisses the notification immediately without a "saved" message.
  ///
  /// Use for the discard path or on unexpected errors.
  static Future<void> stopImmediately() async {
    await FlutterForegroundTask.stopService();
    if (kDebugMode) print('🔕 RecordingNotificationService: stopped (immediate)');
  }
}