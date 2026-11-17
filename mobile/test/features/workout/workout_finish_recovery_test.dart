import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/api/api_client.dart';
import 'package:forge/core/storage/secure_token_storage.dart';
import 'package:forge/features/adaptation/data/adaptation_models.dart';
import 'package:forge/features/adaptation/presentation/adaptation_provider.dart';
import 'package:forge/features/program/data/program_models.dart';
import 'package:forge/features/program/presentation/program_detail_screen.dart';
import 'package:forge/features/workout/data/workout_repository.dart';
import 'package:forge/features/workout/presentation/workout_controller.dart';
import 'package:forge/features/workout/presentation/workout_history_detail_screen.dart';
import 'package:forge/features/workout/presentation/workout_session_screen.dart';
import 'package:forge/features/progress/data/progress_models.dart';
import 'package:forge/features/progress/presentation/progress_provider.dart';

const _workoutId = 'workout-1';
const _completedAt = '2026-11-11T12:30:00Z';

const _emptyProgress = ProgressOverviewData(
  totalExercises: 0,
  improving: 0,
  stable: 0,
  declining: 0,
  insufficientData: 0,
  exercises: [],
);

const _emptyAdaptation = AdaptationOverviewData(
  totalExercises: 0,
  progressLoad: 0,
  progressReps: 0,
  holdLoad: 0,
  keepCurrent: 0,
  reduceStress: 0,
  recommendations: [],
);

void main() {
  group('Workout Finish recovery', () {
    test(
      'keeps Finish successful when the follow-up history request fails',
      () async {
        final backend = _WorkoutBackend()..historyFailuresAfterFinish = 1;
        final environment = _TestEnvironment(backend);
        addTearDown(environment.dispose);

        await environment.container.read(workoutControllerProvider.future);

        final progressSubscription = environment.container.listen(
          progressOverviewProvider,
          (_, _) {},
        );
        final adaptationSubscription = environment.container.listen(
          adaptationOverviewProvider,
          (_, _) {},
        );
        addTearDown(progressSubscription.close);
        addTearDown(adaptationSubscription.close);

        await environment.container.read(progressOverviewProvider.future);
        await environment.container.read(adaptationOverviewProvider.future);
        final progressBuildsBefore = environment.progressBuilds;
        final adaptationBuildsBefore = environment.adaptationBuilds;

        final historyGate = backend.gateNextHistoryResponse();
        final warningPublished = Completer<void>();
        final workoutSubscription = environment.container.listen(
          workoutControllerProvider,
          (_, next) {
            if (next.value?.historySyncError != null &&
                !warningPublished.isCompleted) {
              warningPublished.complete();
            }
          },
        );
        addTearDown(workoutSubscription.close);
        final finishAttempt = await _capture(
          environment.container
              .read(workoutControllerProvider.notifier)
              .finishWorkout(_workoutId),
        );
        await historyGate.started.future;
        expect(historyGate.finished.isCompleted, isFalse);
        historyGate.releaseIfNeeded();
        await historyGate.finished.future;
        await warningPublished.future;

        expect(finishAttempt.error, isNull);
        expect(finishAttempt.value?.status, 'completed');
        expect(
          environment.container
              .read(workoutControllerProvider)
              .requireValue
              .historySyncError,
          contains('history'),
        );
        expect(
          environment.container
              .read(workoutControllerProvider)
              .requireValue
              .currentWorkout,
          isNull,
        );
        expect(backend.serverStatus, 'completed');
        expect(backend.finishRequests, 1);
        expect(backend.historyRequests, 2);

        await environment.container.read(progressOverviewProvider.future);
        await environment.container.read(adaptationOverviewProvider.future);
        expect(environment.progressBuilds, greaterThan(progressBuildsBefore));
        expect(
          environment.adaptationBuilds,
          greaterThan(adaptationBuildsBefore),
        );
      },
    );

    test(
      'reconciles a lost Finish response when the server committed',
      () async {
        final backend = _WorkoutBackend()
          ..loseNextFinishResponse = true
          ..commitBeforeLostResponse = true;
        final environment = _TestEnvironment(backend);
        addTearDown(environment.dispose);

        await environment.container.read(workoutControllerProvider.future);

        final finishAttempt = await _capture(
          environment.container
              .read(workoutControllerProvider.notifier)
              .finishWorkout(_workoutId),
        );

        expect(finishAttempt.error, isNull);
        expect(finishAttempt.value?.status, 'completed');
        expect(
          environment.container
              .read(workoutControllerProvider)
              .requireValue
              .currentWorkout,
          isNull,
        );
        expect(backend.finishRequests, 1);
        expect(backend.detailRequests, 1);
        expect(backend.startRequests, 0);
        expect(backend.createdWorkoutCount, 1);
        expect(backend.serverStatus, 'completed');
      },
    );

    test('retains a logged in-progress workout after reconciliation and permits retry', () async {
      final backend = _WorkoutBackend()
        ..loseNextFinishResponse = true
        ..commitBeforeLostResponse = false;
      final environment = _TestEnvironment(backend);
      addTearDown(environment.dispose);

      await environment.container.read(workoutControllerProvider.future);

      final controller = environment.container.read(
        workoutControllerProvider.notifier,
      );
      final firstAttempt = await _capture(controller.finishWorkout(_workoutId));

      expect(firstAttempt.error, isA<WorkoutException>());
      expect(firstAttempt.value, isNull);
      expect(backend.detailRequests, 1);
      expect(backend.finishRequests, 1);

      final activeWorkout = environment.container
          .read(workoutControllerProvider)
          .requireValue
          .currentWorkout;
      expect(activeWorkout?.id, _workoutId);
      expect(activeWorkout?.isInProgress, isTrue);
      expect(activeWorkout?.exercises.single.sets.single.actualReps, 8);
      expect(backend.serverStatus, 'in_progress');

      final explicitRetry = await _capture(
        controller.finishWorkout(_workoutId),
      );

      expect(explicitRetry.error, isNull);
      expect(explicitRetry.value?.status, 'completed');
      expect(backend.finishRequests, 2);
      expect(backend.createdWorkoutCount, 1);
      expect(backend.startRequests, 0);
      expect(
        environment.container
            .read(workoutControllerProvider)
            .requireValue
            .currentWorkout,
        isNull,
      );
    });

    test('preserves last known state and marks the outcome unknown if reconciliation fails', () async {
      final backend = _WorkoutBackend()
        ..loseNextFinishResponse = true
        ..commitBeforeLostResponse = true
        ..detailFailuresRemaining = 1;
      final environment = _TestEnvironment(backend);
      addTearDown(environment.dispose);

      await environment.container.read(workoutControllerProvider.future);

      final finishAttempt = await _capture(
        environment.container
            .read(workoutControllerProvider.notifier)
            .finishWorkout(_workoutId),
      );

      expect(
        finishAttempt.error,
        isA<WorkoutException>().having(
          (error) => error.message.toLowerCase(),
          'message',
          anyOf(contains('confirm'), contains('unknown')),
        ),
      );
      final activeWorkout = environment.container
          .read(workoutControllerProvider)
          .requireValue
          .currentWorkout;
      expect(activeWorkout?.id, _workoutId);
      expect(activeWorkout?.isInProgress, isTrue);
      expect(activeWorkout?.exercises.single.sets.single.actualReps, 8);
      expect(backend.finishRequests, 1);
      expect(backend.detailRequests, 1);
      expect(backend.startRequests, 0);
      expect(backend.createdWorkoutCount, 1);
    });

    testWidgets(
      'disables Finish while pending and navigates to summary exactly once on success',
      (tester) async {
        final backend = _WorkoutBackend()
          ..finishResponseGate = Completer<void>();
        final environment = _TestEnvironment(backend);
        addTearDown(environment.dispose);
        final navigatorObserver = _NavigatorProbe();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: environment.container,
            child: MaterialApp(
              navigatorObservers: [navigatorObserver],
              home: const WorkoutSessionScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final finishLabel = find.text('FINISH WORKOUT');
        await tester.ensureVisible(finishLabel);
        await tester.tap(finishLabel);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Finish Workout'));

        for (var attempt = 0; attempt < 10; attempt++) {
          await tester.pump(const Duration(milliseconds: 1));
        }

        expect(backend.finishRequests, 1);
        expect(navigatorObserver.replacements, 0);

        final finishButton = tester.widget<FilledButton>(
          find.ancestor(
            of: find.byIcon(Icons.flag_rounded),
            matching: find.byType(FilledButton),
          ),
        );
        expect(finishButton.onPressed, isNull);

        backend.finishResponseGate!.complete();
        await tester.pumpAndSettle();

        expect(backend.finishRequests, 1);
        expect(backend.startRequests, 0);
        expect(navigatorObserver.replacements, 1);
        expect(find.text('Workout Summary'), findsOneWidget);
      },
    );

    testWidgets(
      'does not present a committed Finish as failed when history sync errors',
      (tester) async {
        final backend = _WorkoutBackend()..historyFailuresAfterFinish = 1;
        final environment = _TestEnvironment(backend);
        addTearDown(environment.dispose);
        final navigatorObserver = _NavigatorProbe();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: environment.container,
            child: MaterialApp(
              navigatorObservers: [navigatorObserver],
              home: const WorkoutSessionScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('FINISH WORKOUT'));
        await tester.tap(find.text('FINISH WORKOUT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Finish Workout'));
        await tester.pumpAndSettle();

        expect(backend.serverStatus, 'completed');
        expect(backend.historyRequests, 2);
        expect(navigatorObserver.replacements, 1);
        expect(find.text('Workout Summary'), findsOneWidget);
        expect(find.textContaining('Could not finish'), findsNothing);
        expect(
          environment.container
              .read(workoutControllerProvider)
              .requireValue
              .currentWorkout,
          isNull,
        );
      },
    );

    testWidgets(
      'shows an unknown outcome and leaves a safe retry after reconciliation fails',
      (tester) async {
        final backend = _WorkoutBackend()
          ..loseNextFinishResponse = true
          ..commitBeforeLostResponse = true
          ..detailFailuresRemaining = 1;
        final environment = _TestEnvironment(backend);
        addTearDown(environment.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: environment.container,
            child: const MaterialApp(home: WorkoutSessionScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('FINISH WORKOUT'));
        await tester.tap(find.text('FINISH WORKOUT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Finish Workout'));

        for (var attempt = 0; attempt < 10; attempt++) {
          await tester.pump(const Duration(milliseconds: 1));
        }

        expect(find.textContaining('confirm'), findsOneWidget);
        expect(find.text('Workout Summary'), findsNothing);
        expect(find.text('FINISH WORKOUT'), findsOneWidget);
        expect(backend.finishRequests, 1);
        expect(backend.detailRequests, 1);
        expect(backend.startRequests, 0);
        expect(backend.createdWorkoutCount, 1);
      },
    );

    testWidgets('detail retry reloads workout without sending Finish again', (
      tester,
    ) async {
      final backend = _WorkoutBackend()
        ..serverStatus = 'completed'
        ..detailFailuresRemaining = 1;
      final environment = _TestEnvironment(backend);
      addTearDown(environment.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: environment.container,
          child: const MaterialApp(
            home: WorkoutHistoryDetailScreen(workoutId: _workoutId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load workout'), findsOneWidget);
      expect(backend.finishRequests, 0);

      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load workout'), findsNothing);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(backend.detailRequests, 2);
      expect(backend.finishRequests, 0);
    });

    test('a stale refresh cannot restore a finished workout', () async {
      final backend = _WorkoutBackend();
      final environment = _TestEnvironment(backend);
      addTearDown(environment.dispose);

      await environment.container.read(workoutControllerProvider.future);

      final controller = environment.container.read(
        workoutControllerProvider.notifier,
      );
      final gate = backend.gateNextCurrentResponse();
      final refresh = controller.refresh();
      await gate.started.future;

      try {
        final finishAttempt = await _capture(
          controller.finishWorkout(_workoutId),
        );
        expect(finishAttempt.error, isNull);
        expect(
          environment.container
              .read(workoutControllerProvider)
              .requireValue
              .currentWorkout,
          isNull,
        );
        expect(
          environment.container
              .read(workoutControllerProvider)
              .requireValue
              .history
              .any((workout) => workout.id == _workoutId),
          isTrue,
        );
      } finally {
        gate.releaseIfNeeded();
        await refresh;
      }

      final state = environment.container
          .read(workoutControllerProvider)
          .requireValue;
      expect(state.currentWorkout, isNull);
      expect(state.hasWorkoutInProgress, isFalse);
      expect(
        state.history.where((workout) => workout.id == _workoutId),
        hasLength(1),
      );
      expect(backend.startRequests, 0);
    });

    test('a stale log reload cannot restore a finished workout', () async {
      final backend = _WorkoutBackend();
      final environment = _TestEnvironment(backend);
      addTearDown(environment.dispose);

      await environment.container.read(workoutControllerProvider.future);

      final controller = environment.container.read(
        workoutControllerProvider.notifier,
      );
      final gate = backend.gateNextCurrentResponse();
      final skip = controller.skipExercise('exercise-1');
      await gate.started.future;

      try {
        final finishAttempt = await _capture(
          controller.finishWorkout(_workoutId),
        );
        expect(finishAttempt.error, isNull);
        expect(
          environment.container
              .read(workoutControllerProvider)
              .requireValue
              .currentWorkout,
          isNull,
        );
      } finally {
        gate.releaseIfNeeded();
        await skip;
      }

      final state = environment.container
          .read(workoutControllerProvider)
          .requireValue;
      expect(state.currentWorkout, isNull);
      expect(state.hasWorkoutInProgress, isFalse);
      expect(
        state.history.where((workout) => workout.id == _workoutId),
        hasLength(1),
      );
      expect(backend.startRequests, 0);
    });

    testWidgets(
      'navigates to summary while history synchronization is pending',
      (tester) async {
        final backend = _WorkoutBackend();
        final environment = _TestEnvironment(backend);
        addTearDown(environment.dispose);
        final navigatorObserver = _NavigatorProbe();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: environment.container,
            child: MaterialApp(
              navigatorObservers: [navigatorObserver],
              home: const WorkoutSessionScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final gate = backend.gateNextHistoryResponse();
        var gateStarted = false;
        var navigatedBeforeHistory = false;
        var currentWorkoutClearedBeforeHistory = false;
        try {
          await tester.ensureVisible(find.text('FINISH WORKOUT'));
          await tester.tap(find.text('FINISH WORKOUT'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Finish Workout'));
          await _pumpUntilGateStarted(tester, gate);
          gateStarted = gate.started.isCompleted;

          if (gateStarted) {
            await tester.pumpAndSettle();
            navigatedBeforeHistory = navigatorObserver.replacements == 1;
            currentWorkoutClearedBeforeHistory =
                environment.container
                    .read(workoutControllerProvider)
                    .requireValue
                    .currentWorkout ==
                null;
          }
        } finally {
          gate.releaseIfNeeded();
          if (gate.started.isCompleted) {
            await gate.finished.future;
          }
          await tester.pumpAndSettle();
        }

        expect(gateStarted, isTrue);
        expect(currentWorkoutClearedBeforeHistory, isTrue);
        expect(find.text('Workout Summary'), findsOneWidget);
        expect(
          environment.container
              .read(workoutControllerProvider)
              .requireValue
              .history
              .where((workout) => workout.id == _workoutId),
          hasLength(1),
        );
        expect(navigatedBeforeHistory, isTrue);
      },
    );

    testWidgets(
      'shows background history failure after navigation and allows history refresh',
      (tester) async {
        final backend = _WorkoutBackend();
        final environment = _TestEnvironment(backend);
        addTearDown(environment.dispose);
        final navigatorObserver = _NavigatorProbe();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: environment.container,
            child: MaterialApp(
              navigatorObservers: [navigatorObserver],
              home: const WorkoutSessionScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final gate = backend.gateNextHistoryResponse()
          ..failWithConnectionError = true;
        var gateStarted = false;
        var navigatedBeforeHistory = false;
        try {
          await tester.ensureVisible(find.text('FINISH WORKOUT'));
          await tester.tap(find.text('FINISH WORKOUT'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Finish Workout'));
          await _pumpUntilGateStarted(tester, gate);
          gateStarted = gate.started.isCompleted;
          if (gateStarted) {
            await tester.pumpAndSettle();
            navigatedBeforeHistory = navigatorObserver.replacements == 1;
          }
        } finally {
          gate.releaseIfNeeded();
          if (gate.started.isCompleted) {
            await gate.finished.future;
          }
          await tester.pumpAndSettle();
        }

        final state = environment.container
            .read(workoutControllerProvider)
            .requireValue;
        expect(gateStarted, isTrue);
        expect(navigatorObserver.replacements, 1);
        expect(find.text('Workout Summary'), findsOneWidget);
        expect(
          state.historySyncError,
          contains('history could not be refreshed'),
        );
        expect(state.currentWorkout, isNull);
        expect(
          find.textContaining('history could not be refreshed'),
          findsOneWidget,
        );
        expect(find.text('REFRESH HISTORY'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.runAsync(
          () => environment.container
              .read(workoutControllerProvider.notifier)
              .refresh(),
        );

        final refreshed = environment.container
            .read(workoutControllerProvider)
            .requireValue;
        expect(backend.finishRequests, 1);
        expect(refreshed.currentWorkout, isNull);
        expect(
          refreshed.history.where((workout) => workout.id == _workoutId),
          hasLength(1),
        );
        expect(navigatedBeforeHistory, isTrue);
      },
    );

    test(
      'initial build cannot publish stale empty current after successful Start',
      () async {
        final backend = _WorkoutBackend()..serverStatus = 'none';
        final currentGate = backend.gateNextCurrentResponse();
        final historyGate = backend.gateNextHistoryResponse();
        final environment = _TestEnvironment(backend);
        addTearDown(environment.dispose);

        final buildPublished = Completer<void>();
        var startSucceeded = false;
        var publishedNullAfterStart = false;
        WorkoutState? startedState;
        final subscription = environment.container.listen(
          workoutControllerProvider,
          (_, next) {
            final value = next.value;
            if (!startSucceeded ||
                value == null ||
                identical(value, startedState)) {
              return;
            }

            publishedNullAfterStart = value.currentWorkout == null;
            if (!buildPublished.isCompleted) {
              buildPublished.complete();
            }
          },
        );
        addTearDown(subscription.close);

        environment.container.read(workoutControllerProvider);
        await currentGate.started.future;

        final started = await environment.container
            .read(workoutControllerProvider.notifier)
            .startWorkout('day-1');
        final stateAfterStart = environment.container
            .read(workoutControllerProvider)
            .requireValue;
        startedState = stateAfterStart;
        startSucceeded = true;

        expect(started.id, _startedWorkoutId);
        expect(started.status, 'in_progress');
        expect(stateAfterStart.currentWorkout?.id, started.id);

        currentGate.releaseIfNeeded();
        await currentGate.finished.future;
        await historyGate.started.future;
        historyGate.releaseIfNeeded();
        await historyGate.finished.future;
        await buildPublished.future;

        final current = environment.container
            .read(workoutControllerProvider)
            .requireValue
            .currentWorkout;
        expect(current?.id, started.id);
        expect(current?.status, 'in_progress');
        expect(publishedNullAfterStart, isFalse);
        expect(backend.startRequests, 1);
        expect(backend.createdWorkoutCount, 2);
      },
    );

    test(
      'initial build error cannot replace successful Start with AsyncError',
      () async {
        final backend = _WorkoutBackend()..serverStatus = 'none';
        final currentGate = backend.gateNextCurrentResponse();
        final historyGate = backend.gateNextHistoryResponse()
          ..failWithConnectionError = true;
        final environment = _TestEnvironment(backend);
        addTearDown(environment.dispose);

        final buildSettled = Completer<void>();
        var startSucceeded = false;
        var staleBuildPublishedError = false;
        WorkoutState? startedState;
        final subscription = environment.container.listen(
          workoutControllerProvider,
          (_, next) {
            if (!startSucceeded || buildSettled.isCompleted) {
              return;
            }

            if (next.hasError) {
              staleBuildPublishedError = true;
              buildSettled.complete();
              return;
            }

            if (identical(next.value, startedState)) {
              return;
            }

            buildSettled.complete();
          },
        );
        addTearDown(subscription.close);

        environment.container.read(workoutControllerProvider);
        await currentGate.started.future;

        final started = await environment.container
            .read(workoutControllerProvider.notifier)
            .startWorkout('day-1');
        startedState = environment.container
            .read(workoutControllerProvider)
            .requireValue;
        startSucceeded = true;

        currentGate.releaseIfNeeded();
        await currentGate.finished.future;
        await historyGate.started.future;
        historyGate.releaseIfNeeded();
        await historyGate.finished.future;
        await buildSettled.future;

        final state = environment.container
            .read(workoutControllerProvider)
            .requireValue;
        expect(state.currentWorkout?.id, started.id);
        expect(state.currentWorkout?.status, 'in_progress');
        expect(state.hasWorkoutInProgress, isTrue);
        expect(staleBuildPublishedError, isFalse);
        expect(backend.startRequests, 1);
      },
    );

    test(
      'initial load failures remain visible when no newer state exists',
      () async {
        final backend = _WorkoutBackend();
        final historyGate = backend.gateNextHistoryResponse()
          ..failWithConnectionError = true;
        final environment = _TestEnvironment(backend);
        addTearDown(environment.dispose);

        final initialError = Completer<void>();
        final subscription = environment.container.listen(
          workoutControllerProvider,
          (_, next) {
            if (next.hasError && !initialError.isCompleted) {
              initialError.complete();
            }
          },
        );
        addTearDown(subscription.close);

        environment.container.read(workoutControllerProvider);
        await historyGate.started.future;
        historyGate.releaseIfNeeded();
        await historyGate.finished.future;
        await initialError.future;

        final state = environment.container.read(workoutControllerProvider);
        expect(state.hasError, isTrue);
        expect(state.error, isA<WorkoutException>());
        expect(backend.startRequests, 0);
      },
    );

    testWidgets(
      'Program Detail disables Start until current workout availability loads',
      (tester) async {
        final backend = _WorkoutBackend()..serverStatus = 'none';
        final currentGate = backend.gateNextCurrentResponse();
        final environment = _TestEnvironment(backend);
        addTearDown(environment.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: environment.container,
            child: MaterialApp(
              home: ProgramDetailScreen(program: _testProgram()),
            ),
          ),
        );
        await _pumpUntilGateStarted(tester, currentGate);

        final startButtonFinder = find.ancestor(
          of: find.text('START WORKOUT'),
          matching: find.byType(FilledButton),
        );
        expect(startButtonFinder, findsOneWidget);
        expect(
          tester.widget<FilledButton>(startButtonFinder).onPressed,
          isNull,
        );
        await tester.tap(find.text('START WORKOUT'));
        expect(backend.startRequests, 0);

        currentGate.releaseIfNeeded();
        await currentGate.finished.future;
        await tester.pumpAndSettle();

        expect(
          tester.widget<FilledButton>(startButtonFinder).onPressed,
          isNotNull,
        );
        expect(backend.startRequests, 0);
      },
    );

    test(
      'a late history response cannot erase newer completed history',
      () async {
        final backend = _WorkoutBackend();
        final environment = _TestEnvironment(backend);
        addTearDown(environment.dispose);

        await environment.container.read(workoutControllerProvider.future);

        final controller = environment.container.read(
          workoutControllerProvider.notifier,
        );
        final oldHistoryGate = backend.gateNextHistoryResponse();
        final refresh = controller.refresh();
        await oldHistoryGate.started.future;

        backend.duplicateNextHistoryResponse = true;
        try {
          final finishAttempt = await _capture(
            controller.finishWorkout(_workoutId),
          );
          expect(finishAttempt.error, isNull);
          final historyAfterFinish = environment.container
              .read(workoutControllerProvider)
              .requireValue
              .history;
          expect(
            historyAfterFinish.where((workout) => workout.id == _workoutId),
            hasLength(1),
          );
        } finally {
          oldHistoryGate.releaseIfNeeded();
          await refresh;
        }

        final historyAfterLateRefresh = environment.container
            .read(workoutControllerProvider)
            .requireValue
            .history;
        expect(
          historyAfterLateRefresh.where((workout) => workout.id == _workoutId),
          hasLength(1),
        );
        expect(backend.startRequests, 0);
      },
    );
  });
}

const _startedWorkoutId = 'workout-started';

ProgramDetailData _testProgram() {
  return ProgramDetailData(
    id: 'program-1',
    name: 'Test Program',
    versionNumber: 1,
    generatorVersion: 'test',
    setupRevision: 1,
    currentSetupRevision: 1,
    isOutdated: false,
    goal: 'strength',
    status: 'active',
    createdAt: DateTime.utc(2026, 11, 11),
    days: const [
      ProgramDayData(
        id: 'day-1',
        dayOfWeek: 1,
        dayOrder: 1,
        name: 'Push Day',
        estimatedDurationMinutes: 45,
        exercises: [
          ProgramExerciseData(
            id: 'program-exercise-1',
            exerciseId: 'exercise-definition-1',
            exerciseCode: 'TEST_PRESS',
            exerciseName: 'Test Press',
            exerciseOrder: 1,
            sets: 1,
            minReps: 8,
            maxReps: 12,
            restSeconds: 60,
            reasonCodes: [],
          ),
        ],
      ),
    ],
  );
}

class _ResponseGate {
  final started = Completer<void>();
  final release = Completer<void>();
  final finished = Completer<void>();
  bool failWithConnectionError = false;

  void releaseIfNeeded() {
    if (!release.isCompleted) {
      release.complete();
    }
  }
}

Future<void> _pumpUntilGateStarted(
  WidgetTester tester,
  _ResponseGate gate,
) async {
  for (var attempt = 0; attempt < 20 && !gate.started.isCompleted; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (!gate.started.isCompleted) {
    throw StateError('Expected the gated request to start.');
  }
}

class _WorkoutBackend {
  String serverStatus = 'in_progress';
  bool loseNextFinishResponse = false;
  bool commitBeforeLostResponse = true;
  bool duplicateNextHistoryResponse = false;
  int historyFailuresAfterFinish = 0;
  int detailFailuresRemaining = 0;
  DioExceptionType lostResponseType = DioExceptionType.receiveTimeout;
  Completer<void>? finishResponseGate;
  _ResponseGate? _nextCurrentResponseGate;
  _ResponseGate? _nextHistoryResponseGate;
  final _responseGates = <_ResponseGate>[];

  int currentRequests = 0;
  int historyRequests = 0;
  int finishRequests = 0;
  int detailRequests = 0;
  int skipRequests = 0;
  int startRequests = 0;
  int createdWorkoutCount = 1;

  _ResponseGate gateNextCurrentResponse() {
    final gate = _ResponseGate();
    _nextCurrentResponseGate = gate;
    _responseGates.add(gate);
    return gate;
  }

  _ResponseGate gateNextHistoryResponse() {
    final gate = _ResponseGate();
    _nextHistoryResponseGate = gate;
    _responseGates.add(gate);
    return gate;
  }

  Future<ResponseBody> handle(RequestOptions options) async {
    final path = options.path;
    final method = options.method;

    if (method == 'GET' && path == '/workouts/current') {
      currentRequests++;
      final statusAtRequest = serverStatus;
      final gate = _nextCurrentResponseGate;
      _nextCurrentResponseGate = null;
      if (gate != null) {
        gate.started.complete();
        try {
          await gate.release.future;
        } finally {
          gate.finished.complete();
        }
      }

      if (statusAtRequest != 'in_progress') {
        return _jsonResponse(404, {'detail': 'No active workout'});
      }

      return _jsonResponse(200, _sessionJson(status: statusAtRequest));
    }

    if (method == 'GET' && path == '/workouts/history') {
      historyRequests++;
      final statusAtRequest = serverStatus;
      final gate = _nextHistoryResponseGate;
      _nextHistoryResponseGate = null;
      if (gate != null) {
        gate.started.complete();
        try {
          await gate.release.future;
          if (gate.failWithConnectionError) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          }
        } finally {
          gate.finished.complete();
        }
      }

      if (statusAtRequest == 'completed' && historyFailuresAfterFinish > 0) {
        historyFailuresAfterFinish--;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }

      if (statusAtRequest == 'completed') {
        final summary = _summaryJson();
        if (duplicateNextHistoryResponse) {
          duplicateNextHistoryResponse = false;
          return _jsonResponse(200, [summary, summary]);
        }
        return _jsonResponse(200, [summary]);
      }

      return _jsonResponse(200, <Object?>[]);
    }

    if (method == 'POST' && path == '/workouts/$_workoutId/finish') {
      finishRequests++;
      final gate = finishResponseGate;
      if (gate != null) {
        await gate.future;
      }

      if (loseNextFinishResponse) {
        loseNextFinishResponse = false;
        if (commitBeforeLostResponse) {
          serverStatus = 'completed';
        }
        throw DioException(requestOptions: options, type: lostResponseType);
      }

      serverStatus = 'completed';
      return _jsonResponse(200, _sessionJson());
    }

    if (method == 'POST' && path == '/workouts/exercises/exercise-1/skip') {
      skipRequests++;
      return _jsonResponse(200, _exerciseJson(status: 'skipped'));
    }

    if (method == 'GET' && path == '/workouts/$_workoutId') {
      detailRequests++;
      if (detailFailuresRemaining > 0) {
        detailFailuresRemaining--;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }

      return _jsonResponse(200, _sessionJson());
    }

    if (method == 'POST' && path == '/workouts/start') {
      startRequests++;
      createdWorkoutCount++;
      serverStatus = 'in_progress';
      return _jsonResponse(200, _sessionJson(id: _startedWorkoutId));
    }

    throw StateError('Unexpected test request: $method $path');
  }

  Map<String, dynamic> _sessionJson({String? status, String id = _workoutId}) {
    final sessionStatus = status ?? serverStatus;
    return {
      'id': id,
      'training_program_id': 'program-1',
      'program_day_id': 'day-1',
      'program_version_number': 1,
      'program_name': 'Test Program',
      'day_name': 'Push Day',
      'day_of_week': 1,
      'day_order': 1,
      'status': sessionStatus,
      'notes': null,
      'started_at': '2026-11-11T12:00:00Z',
      'completed_at': sessionStatus == 'completed' ? _completedAt : null,
      'created_at': '2026-11-11T12:00:00Z',
      'exercises': [_exerciseJson()],
    };
  }

  Map<String, dynamic> _exerciseJson({String status = 'completed'}) {
    return {
      'id': 'exercise-1',
      'program_exercise_id': 'program-exercise-1',
      'exercise_id': 'exercise-definition-1',
      'exercise_code': 'TEST_PRESS',
      'exercise_name': 'Test Press',
      'exercise_order': 1,
      'target_sets': 1,
      'target_min_reps': 8,
      'target_max_reps': 12,
      'target_rest_seconds': 60,
      'status': status,
      'notes': null,
      'is_bodyweight': false,
      'sets': [
        {
          'id': 'set-1',
          'set_number': 1,
          'actual_reps': 8,
          'weight_kg': 20.0,
          'rpe': 7.0,
          'is_completed': true,
          'completed_at': '2026-11-11T12:20:00Z',
        },
      ],
    };
  }

  Map<String, dynamic> _summaryJson() {
    return {
      'id': _workoutId,
      'program_version_number': 1,
      'program_name': 'Test Program',
      'day_name': 'Push Day',
      'day_of_week': 1,
      'day_order': 1,
      'status': 'completed',
      'started_at': '2026-11-11T12:00:00Z',
      'completed_at': _completedAt,
    };
  }
}

class _TestEnvironment {
  _TestEnvironment(this.backend) {
    dio = _dioWithAdapter(_FakeAdapter(backend.handle));
    refreshDio = _dioWithAdapter(
      _FakeAdapter((options) async => _jsonResponse(500, {'detail': 'unused'})),
    );
    apiClient = ApiClient(
      tokenStorage: _MemoryTokenStorage(),
      onUnauthorized: () {},
      dio: dio,
      refreshDio: refreshDio,
    );
    repository = WorkoutRepository(apiClient);
    container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        workoutRepositoryProvider.overrideWithValue(repository),
        progressOverviewProvider.overrideWith((ref) async {
          progressBuilds++;
          return _emptyProgress;
        }),
        adaptationOverviewProvider.overrideWith((ref) async {
          adaptationBuilds++;
          return _emptyAdaptation;
        }),
      ],
    );
  }

  final _WorkoutBackend backend;
  late final Dio dio;
  late final Dio refreshDio;
  late final ApiClient apiClient;
  late final WorkoutRepository repository;
  late final ProviderContainer container;
  int progressBuilds = 0;
  int adaptationBuilds = 0;

  void dispose() {
    final gate = backend.finishResponseGate;
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
    for (final responseGate in backend._responseGates) {
      responseGate.releaseIfNeeded();
    }
    container.dispose();
    dio.close(force: true);
    refreshDio.close(force: true);
  }
}

class _MemoryTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> deleteTokens() async {}
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handleRequest);

  final Future<ResponseBody> Function(RequestOptions) _handleRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handleRequest(options);
  }

  @override
  void close({bool force = false}) {}
}

class _NavigatorProbe extends NavigatorObserver {
  int replacements = 0;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacements++;
  }
}

class _CallResult<T> {
  const _CallResult({this.value, this.error});

  final T? value;
  final Object? error;
}

Future<_CallResult<T>> _capture<T>(Future<T> call) async {
  try {
    return _CallResult(value: await call);
  } catch (error) {
    return _CallResult(error: error);
  }
}

Dio _dioWithAdapter(HttpClientAdapter adapter) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://forge-test.invalid/api/v1',
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  )..httpClientAdapter = adapter;
}

ResponseBody _jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
