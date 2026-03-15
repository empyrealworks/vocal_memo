// lib/providers/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vocal_memo/providers/connectivity_provider.dart';
import 'package:vocal_memo/providers/recording_provider.dart';
import 'package:vocal_memo/providers/settings_provider.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/rate_limit_service.dart';

// ─── Core auth ─────────────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ─── Cloud services ────────────────────────────────────────────────────────────

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return CloudSyncService(authService);
});

final firebaseStorageServiceProvider = Provider<FirebaseStorageService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final connService = ref.watch(connectivityServiceProvider);
  return FirebaseStorageService(authService, connService);
});

final rateLimitServiceProvider = Provider<RateLimitService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return RateLimitService(authService);
});

// ─── Derived auth state ────────────────────────────────────────────────────────

final userTierProvider = Provider<UserTier>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authServiceProvider).userTier;
});

final geminiModelProvider = Provider<String>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authServiceProvider).geminiModel;
});

final canTranscribeProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authServiceProvider).canTranscribe;
});

final canTrimProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authServiceProvider).canTrim;
});

final dailyUsageProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(authStateProvider);
  final rateLimitService = ref.watch(rateLimitServiceProvider);
  return rateLimitService.getTodayUsage();
});

// ─── Audio file restore on first login ────────────────────────────────────────
//
// NOTE ON ARCHITECTURE:
//
// Real-time metadata sync (title, transcript, pin, etc.) is now handled
// entirely by the Firestore snapshots() stream inside [RecordingNotifier].
// The provider below ([cloudRestoreProvider]) has a narrower job: it runs
// once per login session to download any missing AUDIO FILES from Firebase
// Storage and write the correct device-local filePath to Hive.
//
// Metadata does NOT need to be fetched here — the stream handles that.
// If there is nothing to download (e.g. the user is on their original device
// and files already exist locally), this provider completes almost instantly.

final _restoreAttemptedProvider = StateProvider<bool>((ref) => false);

/// Triggers a one-time audio file restore on first login.
///
/// Consume this in your root widget to activate it:
///   `ref.watch(cloudRestoreProvider);`
final cloudRestoreProvider = FutureProvider<void>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) {
    // Reset so the restore runs again after re-login
    ref.read(_restoreAttemptedProvider.notifier).state = false;
    return;
  }

  final alreadyAttempted = ref.watch(_restoreAttemptedProvider);
  if (alreadyAttempted) return;

  // Mark before starting to avoid concurrent re-triggers
  ref.read(_restoreAttemptedProvider.notifier).state = true;

  final cloudSyncService = ref.read(cloudSyncServiceProvider);
  final firebaseStorageService = ref.read(firebaseStorageServiceProvider);
  final localStorageService = ref.read(storageServiceProvider);
  final settings = ref.read(settingsProvider);

  // This only downloads audio files — metadata comes via the stream
  await cloudSyncService.restoreFromCloud(
    storageService: firebaseStorageService,
    localStorageService: localStorageService,
    autoDownloadAudio: settings.autoDownloadAudio,
  );

  // Refresh local state so the newly-resolved filePaths are visible
  // before the next Firestore stream event fires
  ref.read(recordingProvider.notifier).refreshRecordings();
});