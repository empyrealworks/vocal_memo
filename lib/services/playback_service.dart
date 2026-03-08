// lib/services/playback_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class PlaybackService {
  final _audioPlayer = AudioPlayer();
  String? _currentFilePath;
  double _playbackSpeed = 1.0;

  bool get isPlaying => _audioPlayer.state == PlayerState.playing;
  bool get isPaused => _audioPlayer.state == PlayerState.paused;
  String? get currentFilePath => _currentFilePath;
  double get playbackSpeed => _playbackSpeed;

  // Listeners
  Stream<Duration> get onDurationChanged => _audioPlayer.onDurationChanged;
  Stream<Duration> get onPositionChanged => _audioPlayer.onPositionChanged;
  Stream<PlayerState> get onPlayerStateChanged => _audioPlayer.onPlayerStateChanged;

  Future<Duration?> load(String filePath) async {
    try {
      _currentFilePath = filePath;
      await _audioPlayer.setSourceDeviceFile(filePath);
      return _audioPlayer.getDuration();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading audio: $e');
      }
      return null;
    }
  }

  Future<void> play() async {
    try {
      // If player has finished or is stopped, start from the beginning
      if (_audioPlayer.state == PlayerState.stopped ||
          _audioPlayer.state == PlayerState.completed) {
        if (_currentFilePath != null) {
          await _audioPlayer.play(DeviceFileSource(_currentFilePath!));
        } else {
          if (kDebugMode) {
            print('No file loaded to play.');
          }
        }
      } else {
        await _audioPlayer.resume();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error playing audio: $e');
      }
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      if (kDebugMode) {
        print('Error pausing audio: $e');
      }
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping audio: $e');
      }
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      if (kDebugMode) {
        print('Error seeking: $e');
      }
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    try {
      _playbackSpeed = speed;
      await _audioPlayer.setPlaybackRate(speed);
    } catch (e) {
      if (kDebugMode) {
        print('Error setting playback speed: $e');
      }
    }
  }

  Future<void> skipForward(Duration duration) async {
    try {
      final currentPosition = await _audioPlayer.getCurrentPosition();
      if (currentPosition != null) {
        final newPosition = currentPosition + duration;
        await seek(newPosition);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error skipping forward: $e');
      }
    }
  }

  Future<void> skipBackward(Duration duration) async {
    try {
      final currentPosition = await _audioPlayer.getCurrentPosition();
      if (currentPosition != null) {
        final newPosition = currentPosition - duration;
        await seek(newPosition.isNegative ? Duration.zero : newPosition);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error skipping backward: $e');
      }
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}