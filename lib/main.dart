import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocal_memo/providers/auth_provider.dart';
import 'package:vocal_memo/providers/recording_provider.dart';
import 'package:vocal_memo/providers/settings_provider.dart';
import 'package:vocal_memo/screens/settings_screen.dart';
import 'package:vocal_memo/services/settings_service.dart';
import 'firebase_options.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize local storage
  await StorageService.init();
  await SettingsService.init();

  final onboardingComplete = StorageService.getOnboardingComplete();

  runApp(ProviderScope(child: VocalMemo(showOnboarding: !onboardingComplete)));
}

class VocalMemo extends ConsumerStatefulWidget {
  final bool showOnboarding;
  const VocalMemo({super.key, required this.showOnboarding});

  @override
  ConsumerState<VocalMemo> createState() => _VocalMemoState();
}

class _VocalMemoState extends ConsumerState<VocalMemo> {
  late bool _showOnboarding;
  // late final onboardingComplete = ref.watch(onboardingProvider);

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.showOnboarding; // ✅ initialize here

    // Listen for auth state changes to trigger sync
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   ref.listen(authStateProvider, (previous, next) {
    //     next.whenData((user) {
    //       if (user != null && previous?.value == null) {
    //         // User just signed in - sync local data to cloud
    //         _syncDataToCloud();
    //       }
    //     });
    //   });
    // });
  }

  Future<void> _syncDataToCloud() async {
    try {
      final recordings = ref.read(recordingProvider);
      final settings = ref.read(settingsProvider);
      final syncService = ref.read(cloudSyncServiceProvider);

      await syncService.syncAllToCloud(
        recordings: recordings,
        settings: settings,
      );

      if (kDebugMode) {
        print('✅ Data synced to cloud');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error syncing data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) {
      next.whenData((user) {
        if (user != null && previous?.value == null) {
          // User just signed in - sync local data to cloud
          _syncDataToCloud();
        }
      });
    });
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vocal Memo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _toThemeMode(settings.themeMode),
      home: _showOnboarding
          ? OnboardingScreen(
              onComplete: () async {
                await StorageService.setOnboardingComplete(true);
                setState(() => _showOnboarding = false);
              },
            )
          : const HomeScreen(),
      routes: {'/settings': (context) => const SettingsScreen()},
    );
  }

  ThemeMode _toThemeMode(String mode) {
    switch (mode) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
