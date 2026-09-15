import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../data/sport_models.dart';
import '../data/sport_repository.dart';

final sportRepositoryProvider = Provider<SportRepository>(
  (ref) {
    final apiClient = ref.read(apiClientProvider);

    return SportRepository(apiClient);
  },
);

class SportController
    extends AsyncNotifier<List<SportActivityData>> {
  SportRepository get _repository =>
      ref.read(sportRepositoryProvider);

  @override
  Future<List<SportActivityData>> build() {
    return _repository.getSports();
  }

  Future<void> addSport({
    required String sportType,
    required int dayOfWeek,
    required int durationMinutes,
    required SportIntensity intensity,
  }) async {
    final created = await _repository.createSport(
      sportType: sportType,
      dayOfWeek: dayOfWeek,
      durationMinutes: durationMinutes,
      intensity: intensity,
    );

    final current =
        state.value ?? await _repository.getSports();

    state = AsyncData(
      _sorted([
        ...current,
        created,
      ]),
    );
  }

  Future<void> editSport({
    required String sportId,
    required String sportType,
    required int dayOfWeek,
    required int durationMinutes,
    required SportIntensity intensity,
  }) async {
    final updated = await _repository.updateSport(
      sportId: sportId,
      sportType: sportType,
      dayOfWeek: dayOfWeek,
      durationMinutes: durationMinutes,
      intensity: intensity,
    );

    final current =
        state.value ?? await _repository.getSports();

    state = AsyncData(
      _sorted([
        for (final sport in current)
          if (sport.id == updated.id)
            updated
          else
            sport,
      ]),
    );
  }

  Future<void> removeSport(
    String sportId,
  ) async {
    await _repository.deleteSport(
      sportId,
    );

    final current =
        state.value ?? await _repository.getSports();

    state = AsyncData(
      [
        for (final sport in current)
          if (sport.id != sportId) sport,
      ],
    );
  }

  Future<void> completeSetup() async {
    await _repository.setConfigured(
      true,
    );

    ref.invalidate(
      onboardingControllerProvider,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      _repository.getSports,
    );
  }

  List<SportActivityData> _sorted(
    List<SportActivityData> sports,
  ) {
    final result = [...sports];

    result.sort(
      (left, right) {
        final dayComparison =
            left.dayOfWeek.compareTo(
          right.dayOfWeek,
        );

        if (dayComparison != 0) {
          return dayComparison;
        }

        return left.sportType.compareTo(
          right.sportType,
        );
      },
    );

    return result;
  }
}

final sportControllerProvider =
    AsyncNotifierProvider<
        SportController,
        List<SportActivityData>>(
  SportController.new,
);