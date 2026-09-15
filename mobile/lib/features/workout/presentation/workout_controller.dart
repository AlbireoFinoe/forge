import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/workout_models.dart';
import '../data/workout_repository.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);

  return WorkoutRepository(apiClient);
});

class WorkoutState {
  const WorkoutState({required this.currentWorkout});

  final WorkoutSessionData? currentWorkout;

  bool get hasWorkoutInProgress => currentWorkout != null;
}

class WorkoutController extends AsyncNotifier<WorkoutState> {
  WorkoutRepository get _repository => ref.read(workoutRepositoryProvider);

  @override
  Future<WorkoutState> build() async {
    final current = await _repository.getCurrentWorkout();

    return WorkoutState(currentWorkout: current);
  }

  Future<WorkoutSessionData> startWorkout(String programDayId) async {
    final workout = await _repository.startWorkout(programDayId);

    state = AsyncData(WorkoutState(currentWorkout: workout));

    return workout;
  }

  Future<void> logSet({
    required String workoutSetId,
    required int actualReps,
    double? weightKg,
    double? rpe,
  }) async {
    await _repository.logSet(
      workoutSetId: workoutSetId,
      actualReps: actualReps,
      weightKg: weightKg,
      rpe: rpe,
    );

    await _reloadCurrent();
  }

  Future<void> skipExercise(String workoutExerciseId) async {
    await _repository.skipExercise(workoutExerciseId);

    await _reloadCurrent();
  }

  Future<WorkoutSessionData> finishWorkout(String workoutId) async {
    final completed = await _repository.finishWorkout(workoutId);

    state = const AsyncData(WorkoutState(currentWorkout: null));

    return completed;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final current = await _repository.getCurrentWorkout();

      return WorkoutState(currentWorkout: current);
    });
  }

  Future<void> _reloadCurrent() async {
    final current = await _repository.getCurrentWorkout();

    state = AsyncData(WorkoutState(currentWorkout: current));
  }
}

final workoutControllerProvider =
    AsyncNotifierProvider<WorkoutController, WorkoutState>(
      WorkoutController.new,
    );
