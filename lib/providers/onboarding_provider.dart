
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

final onboardingProvider =
StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier(StorageService.getOnboardingComplete());
});

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(super.completed);

  Future<void> completeOnboarding() async {
    await StorageService.setOnboardingComplete(true);
    state = true;
  }
}
