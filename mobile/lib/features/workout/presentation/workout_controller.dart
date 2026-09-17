import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/workout_models.dart';
import '../data/workout_repository.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);

  return WorkoutRepository(apiClient);
});

class WorkoutState {
  const WorkoutState({required this.currentWorkout, required this.history});

  final WorkoutSessionData? currentWorkout;
  final List<WorkoutSummaryData> history;

  bool get hasWorkoutInProgress => currentWorkout != null;

  WorkoutSummaryData? get completedToday {
    final now = DateTime.now();

    for (final workout in history) {
      final completedAt = workout.completedAt;

      if (workout.status != 'completed' || completedAt == null) {
        continue;
      }

      final local = completedAt.toLocal();

      if (local.year == now.year &&
          local.month == now.month &&
          local.day == now.day) {
        return workout;
      }
    }

    return null;
  }
}

class WorkoutController extends AsyncNotifier<WorkoutState> {
  WorkoutRepository get _repository => ref.read(workoutRepositoryProvider);

  @override
  Future<WorkoutState> build() async {
    final current = await _repository.getCurrentWorkout();
    final history = await _repository.getHistory();

    return WorkoutState(currentWorkout: current, history: history);
  }

  Future<WorkoutSessionData> startWorkout(String programDayId) async {
    final workout = await _repository.startWorkout(programDayId);
    final previousHistory = state.value?.history ?? <WorkoutSummaryData>[];

    state = AsyncData(
      WorkoutState(currentWorkout: workout, history: previousHistory),
    );

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
    final history = await _repository.getHistory();

    state = AsyncData(WorkoutState(currentWorkout: null, history: history));

    return completed;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final current = await _repository.getCurrentWorkout();
      final history = await _repository.getHistory();

      return WorkoutState(currentWorkout: current, history: history);
    });
  }

  Future<void> _reloadCurrent() async {
    final current = await _repository.getCurrentWorkout();
    final history = state.value?.history ?? await _repository.getHistory();

    state = AsyncData(WorkoutState(currentWorkout: current, history: history));
  }
}

final workoutControllerProvider =
    AsyncNotifierProvider<WorkoutController, WorkoutState>(
      WorkoutController.new,
    );
final workoutDetailProvider = FutureProvider.family<WorkoutSessionData, String>(
  (ref, workoutId) {
    final repository = ref.read(workoutRepositoryProvider);

    return repository.getWorkoutById(workoutId);
  },
);
