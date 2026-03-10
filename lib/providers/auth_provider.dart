// lib/providers/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/rate_limit_service.dart';
import '../services/firebase_storage_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return CloudSyncService(authService);
});

final rateLimitServiceProvider = Provider<RateLimitService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return RateLimitService(authService);
});

final firebaseStorageServiceProvider = Provider<FirebaseStorageService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return FirebaseStorageService(authService);
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final userTierProvider = Provider<UserTier>((ref) {
  // Force re-evaluation when auth state changes
  ref.watch(authStateProvider);
  final authService = ref.watch(authServiceProvider);
  return authService.userTier;
});

final canTranscribeProvider = Provider<bool>((ref) {
  // Force re-evaluation when auth state changes
  ref.watch(authStateProvider);
  final authService = ref.watch(authServiceProvider);
  return authService.canTranscribe;
});

final canTrimProvider = Provider<bool>((ref) {
  // Force re-evaluation when auth state changes
  ref.watch(authStateProvider);
  final authService = ref.watch(authServiceProvider);
  return authService.canTrim;
});

// Provider for daily transcription usage
final dailyUsageProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(authStateProvider); // Re-fetch when auth changes
  final rateLimitService = ref.watch(rateLimitServiceProvider);
  return await rateLimitService.getTodayUsage();
});