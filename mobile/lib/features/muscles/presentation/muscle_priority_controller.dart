import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/muscle_models.dart';
import '../data/muscle_repository.dart';

final muscleRepositoryProvider = Provider<MuscleRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);

  return MuscleRepository(apiClient);
});

class MusclePriorityController extends AsyncNotifier<MusclePrioritiesData> {
  MuscleRepository get _repository => ref.read(muscleRepositoryProvider);

  @override
  Future<MusclePrioritiesData> build() async {
    final muscleGroups = await _repository.getMuscleGroups();

    final priorities = await _repository.getPriorities();

    return MusclePrioritiesData(
      muscleGroups: muscleGroups,
      savedPriorities: {
        for (final item in priorities) item.muscleCode: item.priority,
      },
    );
  }

  Future<void> savePriorities(
    Map<String, MusclePriorityLevel> priorities,
  ) async {
    final current = state.value ?? await build();

    final response = await _repository.updatePriorities(priorities);

    state = AsyncData(
      MusclePrioritiesData(
        muscleGroups: current.muscleGroups,
        savedPriorities: {
          for (final item in response) item.muscleCode: item.priority,
        },
      ),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(build);
  }
}

final musclePriorityControllerProvider =
    AsyncNotifierProvider<MusclePriorityController, MusclePrioritiesData>(
      MusclePriorityController.new,
    );
