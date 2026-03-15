// lib/services/connectivity_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Singleton service that tracks device connectivity state.
///
/// Call [init] once at app startup (before [runApp]).
/// Subscribe to [onConnectivityChanged] to react to online/offline transitions.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller =
  StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  // ─── Public API ───────────────────────────────────────────────

  /// Whether the device currently has a network connection.
  bool get isOnline => _isOnline;

  /// Emits [true] when coming back online, [false] when going offline.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Initialise the service and begin listening for changes.
  /// Must be called once before any feature that depends on [isOnline].
  Future<void> init() async {
    // Seed the initial state before subscribing
    final initialResults = await _connectivity.checkConnectivity();
    _isOnline = _resultsOnline(initialResults);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _resultsOnline(results);
      if (wasOnline != _isOnline) {
        _controller.add(_isOnline);
        debugPrint(_isOnline
            ? '🟢 ConnectivityService: back online'
            : '🔴 ConnectivityService: went offline');
      }
    });
  }

  /// Re-checks connectivity on demand and returns the current status.
  Future<bool> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _resultsOnline(results);
    return _isOnline;
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }

  // ─── Helpers ──────────────────────────────────────────────────

  static bool _resultsOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}