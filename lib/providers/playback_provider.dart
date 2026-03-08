// lib/providers/playback_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/playback_state.dart';
import '../services/playback_service.dart';

// Playback service provider with auto-dispose
final playbackServiceProvider = Provider.autoDispose((ref) {
  final service = PlaybackService();
  ref.onDispose(() => service.dispose());
  return service;
});

class PlaybackNotifier extends StateNotifier<PlaybackState> {
  final PlaybackService _playbackService;

  PlaybackNotifier(this._playbackService) : super(PlaybackState()) {
    _initializeListeners();
  }

  void _initializeListeners() {
    _playbackService.onPlayerStateChanged.listen((playerState) {
      if (playerState == PlayerState.completed) {
        state = state.copyWith(
          playerState: PlayerState.stopped,
          position: state.duration,
        );
      } else {
        state = state.copyWith(playerState: playerState);
      }
    });

    _playbackService.onDurationChanged.listen((duration) {
      state = state.copyWith(duration: duration);
    });

    _playbackService.onPositionChanged.listen((position) {
      state = state.copyWith(position: position);
    });
  }

  Future<void> load(String filePath) async {
    try {
      state = state.copyWith(isLoading: true);
      final duration = await _playbackService.load(filePath);
      state = state.copyWith(
        currentFilePath: filePath,
        duration: duration ?? Duration.zero,
        isLoading: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error loading audio: $e');
      }
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> play() async {
    await _playbackService.play();
  }

  Future<void> pause() async {
    await _playbackService.pause();
  }

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

  Future<void> seek(Duration position) async {
    await _playbackService.seek(position);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _playbackService.setPlaybackSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
  }

  Future<void> skipForward() async {
    await _playbackService.skipForward(const Duration(seconds: 10));
  }

  Future<void> skipBackward() async {
    await _playbackService.skipBackward(const Duration(seconds: 10));
  }

  void reset() {
    state = PlaybackState();
  }

  @override
  void dispose() {
    _playbackService.dispose();
    super.dispose();
  }
}

final playbackProvider = StateNotifierProvider.autoDispose<PlaybackNotifier, PlaybackState>(
      (ref) {
    final playbackService = ref.watch(playbackServiceProvider);
    return PlaybackNotifier(playbackService);
  },
);

// Helper providers
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
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  if (duration.inHours > 0) {
    String twoDigitHours = twoDigits(duration.inHours);
    return '$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds';
  }
  return '$twoDigitMinutes:$twoDigitSeconds';
}