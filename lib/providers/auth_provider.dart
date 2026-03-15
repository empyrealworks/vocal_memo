// lib/providers/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vocal_memo/providers/recording_provider.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/rate_limit_service.dart';
import 'connectivity_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return CloudSyncService(authService, connectivity);
});

final rateLimitServiceProvider = Provider<RateLimitService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return RateLimitService(authService);
});

final firebaseStorageServiceProvider = Provider<FirebaseStorageService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return FirebaseStorageService(authService, connectivity);
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final userTierProvider = Provider<UserTier>((ref) {
  ref.watch(authStateProvider);
  final authService = ref.watch(authServiceProvider);
  return authService.userTier;
});

final geminiModelProvider = Provider<String>((ref) {
  ref.watch(authStateProvider);
  final authService = ref.watch(authServiceProvider);
  return authService.geminiModel;
});

final canTranscribeProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  final authService = ref.watch(authServiceProvider);
  return authService.canTranscribe;
});

final canTrimProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  final authService = ref.watch(authServiceProvider);
  return authService.canTrim;
});

final dailyUsageProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(authStateProvider);
  final rateLimitService = ref.watch(rateLimitServiceProvider);
  return await rateLimitService.getTodayUsage();
});

// ─── Cloud restore on login ────────────────────────────────────────────────────

/// Tracks whether a cloud restore has been attempted in this session so we
/// don't re-run it on every auth state rebuild.
final _restoreAttemptedProvider = StateProvider<bool>((ref) => false);

/// Watches auth state and triggers a one-time cloud restore on first login.
/// Consume this provider in your root widget (e.g. in [main.dart] or
/// [home_screen.dart]) to activate it: `ref.watch(cloudRestoreProvider)`.
final cloudRestoreProvider = FutureProvider<void>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  // Only run when the user is signed in
  if (user == null) {
    // Reset flag on sign-out so the restore runs again after re-login
    ref.read(_restoreAttemptedProvider.notifier).state = false;
    return;
  }

  final alreadyAttempted = ref.watch(_restoreAttemptedProvider);
  if (alreadyAttempted) return;

  // Mark as attempted before starting so concurrent rebuilds don't retrigger
  ref.read(_restoreAttemptedProvider.notifier).state = true;

  final cloudSyncService = ref.read(cloudSyncServiceProvider);
  final firebaseStorageService = ref.read(firebaseStorageServiceProvider);
  final localStorageService = ref.read(storageServiceProvider);

  await cloudSyncService.restoreFromCloud(
    storageService: firebaseStorageService,
    localStorageService: localStorageService,
  );

  // Refresh the recording list after restore
  ref.read(recordingProvider.notifier).refreshRecordings();
});