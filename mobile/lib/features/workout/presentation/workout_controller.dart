import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/workout_models.dart';
import '../../adaptation/presentation/adaptation_provider.dart';
import '../../progress/presentation/progress_provider.dart';
import '../data/workout_repository.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);

  return WorkoutRepository(apiClient);
});

class WorkoutState {
  const WorkoutState({
    required this.currentWorkout,
    required this.history,
    this.historySyncError,
  });

  final WorkoutSessionData? currentWorkout;
  final List<WorkoutSummaryData> history;
  final String? historySyncError;

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

  int _currentRevision = 0;
  int _currentReadGeneration = 0;
  int _historyReadGeneration = 0;
  final Map<String, WorkoutSummaryData> _confirmedCompletions = {};

  @override
  Future<WorkoutState> build() async {
    final currentRevision = _currentRevision;
    final currentGeneration = ++_currentReadGeneration;
    final historyGeneration = ++_historyReadGeneration;
    var currentReadCompleted = false;

    try {
      final current = await _repository.getCurrentWorkout();
      currentReadCompleted = true;
      final history = await _repository.getHistory();

      if (!ref.mounted) {
        return WorkoutState(
          currentWorkout: _withoutConfirmedCompletion(current),
          history: _mergeConfirmedHistory(history),
        );
      }

      final latest = state.value;
      final currentIsCurrent =
          currentRevision == _currentRevision &&
          currentGeneration == _currentReadGeneration;
      final historyIsCurrent = historyGeneration == _historyReadGeneration;

      if (currentIsCurrent) {
        _currentRevision++;
      }

      return WorkoutState(
        currentWorkout: _withoutConfirmedCompletion(
          currentIsCurrent ? current : latest?.currentWorkout,
        ),
        history: _mergeConfirmedHistory(
          historyIsCurrent
              ? history
              : latest?.history ?? const <WorkoutSummaryData>[],
        ),
        historySyncError: latest?.historySyncError,
      );
    } catch (error, stackTrace) {
      if (ref.mounted) {
        final latest = state.value;
        final currentIsStale =
            currentRevision != _currentRevision ||
            currentGeneration != _currentReadGeneration;
        final historyIsStale = historyGeneration != _historyReadGeneration;
        final failureIsStale = currentReadCompleted
            ? currentIsStale || historyIsStale
            : currentIsStale;

        if (latest != null && failureIsStale) {
          return WorkoutState(
            currentWorkout: _withoutConfirmedCompletion(latest.currentWorkout),
            history: _mergeConfirmedHistory(latest.history),
            historySyncError: latest.historySyncError,
          );
        }
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<WorkoutSessionData> startWorkout(String programDayId) async {
    final workout = await _repository.startWorkout(programDayId);
    if (!ref.mounted) {
      return workout;
    }

    _currentRevision++;
    _currentReadGeneration++;
    final previous = state.value;
    final previousHistory = _mergeConfirmedHistory(
      previous?.history ?? const <WorkoutSummaryData>[],
    );

    state = AsyncData(
      WorkoutState(
        currentWorkout: _withoutConfirmedCompletion(workout),
        history: previousHistory,
        historySyncError: previous?.historySyncError,
      ),
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

    if (!ref.mounted) {
      return;
    }

    await _reloadCurrent();
  }

  Future<void> skipExercise(String workoutExerciseId) async {
    await _repository.skipExercise(workoutExerciseId);

    if (!ref.mounted) {
      return;
    }

    await _reloadCurrent();
  }

  Future<WorkoutSessionData> finishWorkout(String workoutId) async {
    late WorkoutSessionData completed;
    try {
      completed = await _repository.finishWorkout(workoutId);
    } on WorkoutException catch (error) {
      if (!error.isAmbiguousTransport) {
        rethrow;
      }
      if (!ref.mounted) {
        rethrow;
      }

      completed = await _reconcileFinishWorkout(workoutId);
    }

    if (completed.id != workoutId || completed.status != 'completed') {
      throw const WorkoutException(
        'Could not confirm whether this workout finished. Check status or retry Finish.',
        kind: WorkoutExceptionKind.finishOutcomeUnknown,
      );
    }

    if (!ref.mounted) {
      return completed;
    }

    final summary = _summaryFor(completed);
    _confirmedCompletions[completed.id] = summary;
    _currentRevision++;
    _currentReadGeneration++;
    _historyReadGeneration++;

    final previous = state.value;
    final currentWorkout = previous?.currentWorkout;
    state = AsyncData(
      WorkoutState(
        currentWorkout: currentWorkout?.id == workoutId ? null : currentWorkout,
        history: _mergeConfirmedHistory(
          previous?.history ?? const <WorkoutSummaryData>[],
        ),
        historySyncError: previous?.historySyncError,
      ),
    );

    ref.invalidate(progressOverviewProvider);
    ref.invalidate(adaptationOverviewProvider);

    final historyGeneration = ++_historyReadGeneration;
    final historyRequest = _repository.getHistory();
    unawaited(_synchronizeHistory(historyGeneration, historyRequest));

    return completed;
  }

  Future<void> refresh() async {
    if (!ref.mounted) {
      return;
    }

    final currentRevision = _currentRevision;
    final currentGeneration = ++_currentReadGeneration;
    final historyGeneration = ++_historyReadGeneration;

    late WorkoutSessionData? current;
    try {
      current = await _repository.getCurrentWorkout();
    } catch (error, stackTrace) {
      if (_canPublishCurrent(currentRevision, currentGeneration) &&
          state.value == null) {
        state = AsyncError(error, stackTrace);
      }
      return;
    }

    if (_canPublishCurrent(currentRevision, currentGeneration)) {
      _publishCurrentRead(current);
    }

    try {
      final history = await _repository.getHistory();
      _publishHistoryRead(historyGeneration, history);
    } on WorkoutException {
      _publishHistorySyncError(
        historyGeneration,
        'Workout history could not be refreshed. Try again.',
      );
    } catch (_) {
      _publishHistorySyncError(
        historyGeneration,
        'An unexpected error prevented workout history from syncing. Try again.',
      );
    }
  }

  Future<void> _reloadCurrent() async {
    if (!ref.mounted) {
      return;
    }

    final needsHistory = state.value == null;
    final currentRevision = _currentRevision;
    final currentGeneration = ++_currentReadGeneration;
    final current = await _repository.getCurrentWorkout();

    if (!_canPublishCurrent(currentRevision, currentGeneration)) {
      return;
    }

    _publishCurrentRead(current);

    if (!needsHistory) {
      return;
    }

    final historyGeneration = ++_historyReadGeneration;
    final history = await _repository.getHistory();
    _publishHistoryRead(historyGeneration, history);
  }

  bool _canPublishCurrent(int revision, int generation) {
    return ref.mounted &&
        revision == _currentRevision &&
        generation == _currentReadGeneration;
  }

  void _publishCurrentRead(WorkoutSessionData? current) {
    if (!ref.mounted) {
      return;
    }

    final previous = state.value;
    _currentRevision++;
    state = AsyncData(
      WorkoutState(
        currentWorkout: _withoutConfirmedCompletion(current),
        history: _mergeConfirmedHistory(
          previous?.history ?? const <WorkoutSummaryData>[],
        ),
        historySyncError: previous?.historySyncError,
      ),
    );
  }

  Future<void> _synchronizeHistory(
    int generation,
    Future<List<WorkoutSummaryData>> historyRequest,
  ) async {
    try {
      final history = await historyRequest;
      _publishHistoryRead(generation, history);
    } on WorkoutException {
      _publishHistorySyncError(
        generation,
        'Workout finished, but history could not be refreshed. Refresh history to sync.',
      );
    } catch (_) {
      _publishHistorySyncError(
        generation,
        'Workout finished, but an unexpected error prevented history from syncing. Refresh history to sync.',
      );
    }
  }

  void _publishHistoryRead(int generation, List<WorkoutSummaryData> history) {
    if (!ref.mounted || generation != _historyReadGeneration) {
      return;
    }

    final latest = state.value;
    state = AsyncData(
      WorkoutState(
        currentWorkout: latest?.currentWorkout,
        history: _mergeConfirmedHistory(history),
      ),
    );
  }

  void _publishHistorySyncError(int generation, String message) {
    if (!ref.mounted || generation != _historyReadGeneration) {
      return;
    }

    final latest = state.value;
    state = AsyncData(
      WorkoutState(
        currentWorkout: latest?.currentWorkout,
        history: _mergeConfirmedHistory(
          latest?.history ?? const <WorkoutSummaryData>[],
        ),
        historySyncError: message,
      ),
    );
  }

  WorkoutSessionData? _withoutConfirmedCompletion(WorkoutSessionData? workout) {
    if (workout != null && _confirmedCompletions.containsKey(workout.id)) {
      return null;
    }

    return workout;
  }

  Future<WorkoutSessionData> _reconcileFinishWorkout(String workoutId) async {
    late WorkoutSessionData workout;
    try {
      workout = await _repository.getWorkoutById(workoutId);
    } catch (error) {
      throw WorkoutException(
        'Could not confirm whether this workout finished. Check status or retry Finish.',
        kind: WorkoutExceptionKind.finishOutcomeUnknown,
        cause: error,
      );
    }

    if (workout.id == workoutId && workout.status == 'completed') {
      return workout;
    }

    if (workout.id == workoutId && workout.status == 'in_progress') {
      throw const WorkoutException(
        'Workout is still in progress. Your logged sets are saved; you can retry Finish.',
        kind: WorkoutExceptionKind.finishNotConfirmed,
      );
    }

    throw const WorkoutException(
      'Could not confirm whether this workout finished. Check status or retry Finish.',
      kind: WorkoutExceptionKind.finishOutcomeUnknown,
    );
  }

  WorkoutSummaryData _summaryFor(WorkoutSessionData workout) {
    return WorkoutSummaryData(
      id: workout.id,
      programVersionNumber: workout.programVersionNumber,
      programName: workout.programName,
      dayName: workout.dayName,
      dayOfWeek: workout.dayOfWeek,
      dayOrder: workout.dayOrder,
      status: workout.status,
      startedAt: workout.startedAt,
      completedAt: workout.completedAt,
    );
  }

  List<WorkoutSummaryData> _mergeConfirmedHistory(
    List<WorkoutSummaryData> history,
  ) {
    final merged = <String, WorkoutSummaryData>{};

    for (final item in history) {
      merged.putIfAbsent(item.id, () => item);
    }

    for (final entry in _confirmedCompletions.entries) {
      merged[entry.key] = entry.value;
    }

    return [
      ..._confirmedCompletions.values.toList().reversed,
      ...merged.values.where(
        (item) => !_confirmedCompletions.containsKey(item.id),
      ),
    ];
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
