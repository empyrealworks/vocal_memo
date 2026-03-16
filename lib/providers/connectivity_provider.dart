// lib/providers/connectivity_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import '../services/sync_queue_service.dart';

/// Global [ConnectivityService] instance. Initialised in [main] before runApp.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Streams [true] / [false] as the device connectivity changes.
/// The initial value is read synchronously from [ConnectivityService.isOnline].
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

/// Synchronous snapshot of the current online/offline status.
/// Reads from [connectivityStreamProvider] and falls back to
/// [ConnectivityService.isOnline] when the stream has not yet emitted.
final isOnlineProvider = Provider<bool>((ref) {
  final stream = ref.watch(connectivityStreamProvider);
  return stream.when(
    data: (online) => online,
    loading: () => ConnectivityService().isOnline,
    error: (_, __) => ConnectivityService().isOnline,
  );
});

/// Global [SyncQueueService] instance.
final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  return SyncQueueService();
});