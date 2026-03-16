import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vocal_memo/providers/auth_provider.dart';
import 'package:vocal_memo/providers/connectivity_provider.dart';
import 'package:vocal_memo/providers/recording_provider.dart';
import 'package:vocal_memo/providers/settings_provider.dart';
import 'package:vocal_memo/screens/settings_screen.dart';
import 'package:vocal_memo/services/connectivity_service.dart';
import 'package:vocal_memo/services/settings_service.dart';
import 'package:vocal_memo/services/sync_queue_service.dart';
import 'package:vocal_memo/widgets/connectivity_icon.dart';
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

  // Initialize connectivity monitoring (before UI)
  await ConnectivityService().init();

  // Initialize the sync queue (Hive box)
  await SyncQueueService().init();

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

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.showOnboarding;
  }

  // ─── Auth-triggered sync ──────────────────────────────────────

  Future<void> _syncDataToCloud() async {
    try {
      final recordings = ref.read(recordingProvider);
      final settings = ref.read(settingsProvider);
      final syncService = ref.read(cloudSyncServiceProvider);

      await syncService.syncAllToCloud(
        recordings: recordings,
        settings: settings,
      );

      if (kDebugMode) print('✅ Data synced to cloud');
    } catch (e) {
      if (kDebugMode) print('❌ Error syncing data: $e');
    }
  }

  // ─── Sync queue drain (called when connectivity restored) ─────

  Future<void> _drainSyncQueue(BuildContext context) async {
    final notifier = ref.read(recordingProvider.notifier);

    int syncedCount = 0;
    await notifier.drainSyncQueue(
      onJobComplete: (_) => syncedCount++,
    );

    if (syncedCount > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncedCount == 1
                ? '☁️ 1 recording backed up successfully.'
                : '☁️ $syncedCount recordings backed up successfully.',
          ),
          backgroundColor: AppTheme.teal,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Auth sync listener stays here (it doesn't need a ScaffoldMessenger context)
    ref.listen(authStateProvider, (previous, next) {
      next.whenData((user) {
        if (user != null && previous?.value == null) {
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

      // ── Inject connectivity banner + drain trigger globally ───
      builder: (context, child) {
        // 2. Wrap in a Consumer to get a valid build context for ref.listen
        return Consumer(
          builder: (consumerContext, consumerRef, _) {

            // Now safely inside a Consumer's build method!
            consumerRef.listen<AsyncValue<bool>>(connectivityStreamProvider, (prev, next) {
              next.whenData((online) {
                if (online && prev?.value == false) {
                  // Use the consumerContext, which is safely below MaterialApp
                  _drainSyncQueue(consumerContext);
                }
              });
            });

            return ConnectivityIcon(child: child ?? const SizedBox.shrink());
          },
        );
      },
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