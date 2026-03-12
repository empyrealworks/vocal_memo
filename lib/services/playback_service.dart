// lib/services/playback_service.dart
//
// Complete rewrite: audioplayers replaced by audio_waveforms PlayerController.
// This service is used by PlaybackNotifier (trim screen, etc.).
// The expandable_recording_card manages its own PlayerController directly.
//
// API surface is intentionally unchanged so trim_screen.dart needs no edits.

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';

class PlaybackService {
  final PlayerController _controller = PlayerController();
  String? _currentFilePath;
  double _playbackSpeed = 1.0;

  String? get currentFilePath => _currentFilePath;
  double get playbackSpeed => _playbackSpeed;

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Emits the current playback position as a Duration (maps from ms int).
  Stream<Duration> get onPositionChanged =>
      _controller.onCurrentDurationChanged
          .map((ms) => Duration(milliseconds: ms));

  /// Forwards audio_waveforms PlayerState changes.
  Stream<PlayerState> get onPlayerStateChanged =>
      _controller.onPlayerStateChanged;

  /// Fires once when a track finishes playing naturally.
  Stream<void> get onCompletion => _controller.onCompletion;

  // ── Playback API ──────────────────────────────────────────────────────────

  /// Prepares [filePath] for playback and returns its total duration.
  ///
  /// Calling load() again while something is playing will stop the current
  /// track first, then prepare the new one.
  Future<Duration?> load(String filePath) async {
    try {
      _currentFilePath = filePath;

      // Stop any current playback before re-preparing.
      if (_controller.playerState == PlayerState.playing ||
          _controller.playerState == PlayerState.paused) {
        await _controller.stopPlayer();
      }

      await _controller.preparePlayer(
        path: filePath,
        // Waveform extraction is not needed here — this controller is purely
        // for audio output; the card / trim screen have their own controllers
        // for visualisation.
        shouldExtractWaveform: false,
      );

      // maxDuration is populated synchronously after preparePlayer().
      return Duration(milliseconds: _controller.maxDuration);
    } catch (e) {
      if (kDebugMode) print('PlaybackService.load error: $e');
      return null;
    }
  }

  Future<void> play() async {
    try {
      await _controller.startPlayer();
    } catch (e) {
      if (kDebugMode) print('PlaybackService.play error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _controller.pausePlayer();
    } catch (e) {
      if (kDebugMode) print('PlaybackService.pause error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _controller.stopPlayer();
    } catch (e) {
      if (kDebugMode) print('PlaybackService.stop error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _controller.seekTo(position.inMilliseconds);
    } catch (e) {
      if (kDebugMode) print('PlaybackService.seek error: $e');
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    try {
      _playbackSpeed = speed;
      await _controller.setRate(speed);
    } catch (e) {
      if (kDebugMode) print('PlaybackService.setRate error: $e');
    }
  }

  Future<void> skipForward(Duration by) async {
    try {
      final currentMs = await _controller.getDuration(DurationType.current) ?? 0;
      final newMs = (currentMs + by.inMilliseconds)
          .clamp(0, _controller.maxDuration);
      await _controller.seekTo(newMs);
    } catch (e) {
      if (kDebugMode) print('PlaybackService.skipForward error: $e');
    }
  }

  Future<void> skipBackward(Duration by) async {
    try {
      final currentMs = await _controller.getDuration(DurationType.current) ?? 0;
      final newMs = (currentMs - by.inMilliseconds)
          .clamp(0, _controller.maxDuration);
      await _controller.seekTo(newMs);
    } catch (e) {
      if (kDebugMode) print('PlaybackService.skipBackward error: $e');
    }
  }

  void dispose() {
    _controller.dispose();
  }
}