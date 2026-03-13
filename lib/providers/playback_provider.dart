// lib/providers/playback_provider.dart
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/playback_state.dart';
import '../services/playback_service.dart';

// ---------------------------------------------------------------------------
// activeCardPlayerProvider
//
// Tracks which recording card currently owns audio focus.
// Holds recording.id of the most recently started card.
// Other open cards listen and pause themselves when this changes.
// ---------------------------------------------------------------------------
final activeCardPlayerProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// PlaybackService provider
// ---------------------------------------------------------------------------
final playbackServiceProvider = Provider.autoDispose((ref) {
  final service = PlaybackService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ---------------------------------------------------------------------------
// PlaybackNotifier
// ---------------------------------------------------------------------------
class PlaybackNotifier extends StateNotifier<PlaybackState> {
  final PlaybackService _playbackService;

  PlaybackNotifier(this._playbackService) : super(PlaybackState()) {
    _initializeListeners();
  }

  void _initializeListeners() {
    // Position stream: audio_waveforms fires every ~100 ms by default.
    _playbackService.onPositionChanged.listen((position) {
      state = state.copyWith(position: position);
    });

    // Player state changes (playing / paused / stopped / initialized).
    _playbackService.onPlayerStateChanged.listen((playerState) {
      state = state.copyWith(playerState: playerState);
    });

    // Natural completion: snap position to end of track.
    _playbackService.onCompletion.listen((_) {
      state = state.copyWith(
        playerState: PlayerState.stopped,
        position: state.duration,
      );
    });
  }

  Future<void> load(String filePath) async {
    try {
      state = state.copyWith(isLoading: true);
      final duration = await _playbackService.load(filePath);
      state = state.copyWith(
        currentFilePath: filePath,
        duration: duration ?? Duration.zero,
        position: Duration.zero,
        isLoading: false,
      );
    } catch (e) {
      if (kDebugMode) print('Error loading audio: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> play() async => _playbackService.play();
  Future<void> pause() async => _playbackService.pause();

  Future<void> stop() async {
    await _playbackService.stop();
    state = state.copyWith(
      playerState: PlayerState.stopped,
      position: Duration.zero,
    );
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) async =>
      _playbackService.seek(position);

  Future<void> setPlaybackSpeed(double speed) async {
    await _playbackService.setPlaybackSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
  }

  Future<void> skipForward() async =>
      _playbackService.skipForward(const Duration(seconds: 10));

  Future<void> skipBackward() async =>
      _playbackService.skipBackward(const Duration(seconds: 10));

  void reset() => state = PlaybackState();

  @override
  void dispose() {
    _playbackService.dispose();
    super.dispose();
  }
}

final playbackProvider =
StateNotifierProvider.autoDispose<PlaybackNotifier, PlaybackState>(
      (ref) {
    final service = ref.watch(playbackServiceProvider);
    return PlaybackNotifier(service);
  },
);

// Helper providers (used by trim_screen, speed_selector, etc.)
final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(playbackProvider).isPlaying;
});

final playbackProgressProvider = Provider<double>((ref) {
  return ref.watch(playbackProvider).progress;
});

final formattedPositionProvider = Provider<String>((ref) {
  final position = ref.watch(playbackProvider).position;
  return _formatDuration(position);
});

final formattedDurationProvider = Provider<String>((ref) {
  final duration = ref.watch(playbackProvider).duration;
  return _formatDuration(duration);
});

String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final mm = twoDigits(duration.inMinutes.remainder(60));
  final ss = twoDigits(duration.inSeconds.remainder(60));
  if (duration.inHours > 0) {
    return '${twoDigits(duration.inHours)}:$mm:$ss';
  }
  return '$mm:$ss';
}