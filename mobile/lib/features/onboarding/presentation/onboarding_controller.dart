import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/onboarding_models.dart';
import '../data/onboarding_repository.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);

  return OnboardingRepository(apiClient);
});

class OnboardingController extends AsyncNotifier<OnboardingData> {
  OnboardingRepository get _repository =>
      ref.read(onboardingRepositoryProvider);

  @override
  Future<OnboardingData> build() {
    return _repository.getOnboarding();
  }

  Future<void> setGoal({
    required TrainingGoal primaryGoal,
    required List<TrainingGoal> secondaryGoals,
  }) async {
    final updatedGoal = await _repository.updateGoal(
      primaryGoal: primaryGoal,
      secondaryGoals: secondaryGoals,
    );

    final current = state.value ?? await _repository.getOnboarding();

    state = AsyncData(
      OnboardingData(
        goal: updatedGoal,
        trainingPreferences: current.trainingPreferences,
      ),
    );
  }

  Future<void> setTrainingPreferences({
    required int daysPerWeek,
    required int sessionDurationMinutes,
    required List<int> availableDays,
    required bool noDedicatedLegDay,
    required bool armSpecialization,
  }) async {
    final updatedPreferences = await _repository.updateTrainingPreferences(
      daysPerWeek: daysPerWeek,
      sessionDurationMinutes: sessionDurationMinutes,
      availableDays: availableDays,
      noDedicatedLegDay: noDedicatedLegDay,
      armSpecialization: armSpecialization,
    );

    final current = state.value ?? await _repository.getOnboarding();

    state = AsyncData(
      OnboardingData(
        goal: current.goal,
        trainingPreferences: updatedPreferences,
      ),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(_repository.getOnboarding);
  }
}

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingData>(
      OnboardingController.new,
    );
