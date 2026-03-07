
import 'package:flutter_riverpod/legacy.dart';
import '../services/storage_service.dart';

final onboardingProvider =
StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier(StorageService.getOnboardingComplete());
});

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(bool completed) : super(completed);

  Future<void> completeOnboarding() async {
    await StorageService.setOnboardingComplete(true);
    state = true;
  }
}
