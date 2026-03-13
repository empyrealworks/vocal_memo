// lib/models/playback_state.dart
//
// PlayerState is imported from audio_waveforms (not audioplayers).
// audio_waveforms exports: PlayerState.playing / .paused / .stopped / .initialized
// The isPlaying / isPaused / isStopped getters work identically.

import 'package:audio_waveforms/audio_waveforms.dart';

class PlaybackState {
  final String? currentFilePath;
  final Duration duration;
  final Duration position;
  final PlayerState playerState;
  final double playbackSpeed;
  final bool isLoading;

  PlaybackState({
    this.currentFilePath,
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.playerState = PlayerState.stopped,
    this.playbackSpeed = 1.0,
    this.isLoading = false,
  });

  bool get isPlaying => playerState == PlayerState.playing;
  bool get isPaused  => playerState == PlayerState.paused;
  bool get isStopped => playerState == PlayerState.stopped;

  double get progress {
    if (duration.inMilliseconds == 0) return 0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  PlaybackState copyWith({
    String? currentFilePath,
    Duration? duration,
    Duration? position,
    PlayerState? playerState,
    double? playbackSpeed,
    bool? isLoading,
  }) =>
      PlaybackState(
        currentFilePath: currentFilePath ?? this.currentFilePath,
        duration:        duration        ?? this.duration,
        position:        position        ?? this.position,
        playerState:     playerState     ?? this.playerState,
        playbackSpeed:   playbackSpeed   ?? this.playbackSpeed,
        isLoading:       isLoading       ?? this.isLoading,
      );
}