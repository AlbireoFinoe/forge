import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../../../core/theme/forge_theme.dart';
import '../../exercise/presentation/exercise_detail_sheet.dart';
import '../../adaptation/data/adaptation_models.dart';
import '../../adaptation/presentation/adaptation_guidance.dart';
import '../../adaptation/presentation/adaptation_provider.dart';
import '../data/workout_models.dart';
import '../data/workout_repository.dart';
import 'workout_controller.dart';
import 'workout_history_detail_screen.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key});

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen>
    with WidgetsBindingObserver {
  bool _isFinishing = false;

  Timer? _restTimer;
  DateTime? _restEndsAt;

  int _restRemainingSeconds = 0;
  int _restTotalSeconds = 0;

  String? _restExerciseName;
  String? _restExerciseId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _restTimer?.cancel();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncRestTimer();
    }
  }

  bool _hasRemainingSetInExercise(
    WorkoutExerciseData exercise,
    WorkoutSetData workoutSet,
  ) {
    for (final candidate in exercise.sets) {
      if (candidate.id == workoutSet.id) {
        continue;
      }

      if (!candidate.isCompleted) {
        return true;
      }
    }

    return false;
  }

  void _startRestTimer(WorkoutExerciseData exercise) {
    final seconds = exercise.targetRestSeconds;

    if (seconds <= 0 || !mounted) {
      return;
    }

    _restTimer?.cancel();

    final endsAt = DateTime.now().add(Duration(seconds: seconds));

    setState(() {
      _restEndsAt = endsAt;
      _restRemainingSeconds = seconds;
      _restTotalSeconds = seconds;
      _restExerciseName = exercise.exerciseName;
      _restExerciseId = exercise.id;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncRestTimer();
    });
  }

  void _syncRestTimer() {
    if (!mounted) {
      return;
    }

    final endsAt = _restEndsAt;

    if (endsAt == null) {
      return;
    }

    final remainingMilliseconds = endsAt
        .difference(DateTime.now())
        .inMilliseconds;

    if (remainingMilliseconds <= 0) {
      _restTimer?.cancel();
      _restTimer = null;

      setState(() {
        _restEndsAt = null;
        _restRemainingSeconds = 0;
        _restTotalSeconds = 0;
        _restExerciseName = null;
        _restExerciseId = null;
      });

      return;
    }

    final remainingSeconds = (remainingMilliseconds / 1000).ceil();

    if (remainingSeconds == _restRemainingSeconds) {
      return;
    }

    setState(() {
      _restRemainingSeconds = remainingSeconds;
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    _restTimer = null;

    if (!mounted) {
      return;
    }

    setState(() {
      _restEndsAt = null;
      _restRemainingSeconds = 0;
      _restTotalSeconds = 0;
      _restExerciseName = null;
      _restExerciseId = null;
    });
  }

  void _addThirtySeconds() {
    final endsAt = _restEndsAt;

    if (endsAt == null || !mounted) {
      return;
    }

    setState(() {
      _restEndsAt = endsAt.add(const Duration(seconds: 30));

      _restTotalSeconds += 30;
      _restRemainingSeconds += 30;
    });
  }

  Future<void> _logSet(
    WorkoutExerciseData exercise,
    WorkoutSetData workoutSet,
  ) async {
    WorkoutSetData? previousSet;

    for (final candidate in exercise.sets) {
      if (!candidate.isCompleted ||
          candidate.setNumber >= workoutSet.setNumber) {
        continue;
      }

      if (previousSet == null || candidate.setNumber > previousSet.setNumber) {
        previousSet = candidate;
      }
    }

    final result = await showModalBottomSheet<_SetLogResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _SetLogSheet(
          exercise: exercise,
          workoutSet: workoutSet,
          previousSet: previousSet,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final wasAlreadyCompleted = workoutSet.isCompleted;

    final shouldStartRest =
        !wasAlreadyCompleted &&
        exercise.targetRestSeconds > 0 &&
        _hasRemainingSetInExercise(exercise, workoutSet);

    try {
      await ref
          .read(workoutControllerProvider.notifier)
          .logSet(
            workoutSetId: workoutSet.id,
            actualReps: result.actualReps,
            weightKg: result.weightKg,
            rpe: result.rpe,
          );

      if (shouldStartRest && mounted) {
        _startRestTimer(exercise);
      }
    } on WorkoutException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save this set.')));
    }
  }

  Future<void> _skipExercise(WorkoutExerciseData exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Skip exercise?'),
          content: Text('Skip ${exercise.exerciseName} for this workout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Skip'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(workoutControllerProvider.notifier)
          .skipExercise(exercise.id);

      if (_restExerciseId == exercise.id) {
        _skipRest();
      }
    } on WorkoutException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _finishWorkout(WorkoutSessionData workout) async {
    if (_isFinishing || workout.pendingExercises > 0) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Finish workout?'),
          content: const Text(
            'Your completed sets will be saved '
            'to your workout history.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Finish Workout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isFinishing = true;
    });

    try {
      final completed = await ref
          .read(workoutControllerProvider.notifier)
          .finishWorkout(workout.id);

      if (!mounted) {
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) {
            return WorkoutHistoryDetailScreen(
              workoutId: completed.id,
              title: 'Workout Summary',
            );
          },
        ),
      );
    } on WorkoutException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not finish this workout.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFinishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = ref.watch(workoutControllerProvider);

    final adaptation = ref.watch(adaptationOverviewProvider);

    final adaptationByExerciseCode = adaptation.maybeWhen(
      data: (overview) {
        return <String, AdaptationRecommendationData>{
          for (final recommendation in overview.recommendations)
            recommendation.exerciseCode: recommendation,
        };
      },
      orElse: () {
        return const <String, AdaptationRecommendationData>{};
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('WORKOUT')),
      bottomNavigationBar:
          _restRemainingSeconds > 0 && _restExerciseName != null
          ? SafeArea(
              top: false,
              child: _RestTimerCard(
                exerciseName: _restExerciseName!,
                remainingSeconds: _restRemainingSeconds,
                totalSeconds: _restTotalSeconds,
                onSkip: _skipRest,
                onAddThirtySeconds: _addThirtySeconds,
              ),
            )
          : null,
      body: workout.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 16),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      ref.read(workoutControllerProvider.notifier).refresh();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (state) {
          final session = state.currentWorkout;

          if (session == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No workout is currently in progress.'),
              ),
            );
          }

          return _WorkoutContent(
            workout: session,
            adaptationByExerciseCode: adaptationByExerciseCode,
            isFinishing: _isFinishing,
            restRemainingSeconds: _restRemainingSeconds,
            restExerciseId: _restExerciseId,
            onLogSet: _logSet,
            onSkipExercise: _skipExercise,
            onFinish: () {
              _finishWorkout(session);
            },
          );
        },
      ),
    );
  }
}

class _WorkoutContent extends StatelessWidget {
  const _WorkoutContent({
    required this.workout,
    required this.adaptationByExerciseCode,
    required this.isFinishing,
    required this.restRemainingSeconds,
    required this.restExerciseId,
    required this.onLogSet,
    required this.onSkipExercise,
    required this.onFinish,
  });

  final WorkoutSessionData workout;

  final Map<String, AdaptationRecommendationData> adaptationByExerciseCode;

  final bool isFinishing;

  final int restRemainingSeconds;
  final String? restExerciseId;

  final void Function(WorkoutExerciseData exercise, WorkoutSetData workoutSet)
  onLogSet;

  final void Function(WorkoutExerciseData exercise) onSkipExercise;

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final resolvedExercises = workout.exercises
        .where((exercise) => exercise.isCompleted || exercise.isSkipped)
        .length;

    final exerciseProgress = workout.exercises.isEmpty
        ? 0.0
        : resolvedExercises / workout.exercises.length;

    final setProgress = workout.totalSets == 0
        ? 0.0
        : workout.completedSets / workout.totalSets;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          ForgeSpacing.lg,
          ForgeSpacing.lg,
          ForgeSpacing.lg,
          ForgeSpacing.xxl,
        ),
        children: [
          Text(
            workout.dayName.toUpperCase(),
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),

          const SizedBox(height: 6),

          Text(
            '${weekdayLabel(workout.dayOfWeek)} '
            '\u2022 Program v${workout.programVersionNumber}',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: ForgeColors.textSecondary),
          ),

          const SizedBox(height: ForgeSpacing.xl),

          _WorkoutProgressPanel(
            completedExercises: resolvedExercises,
            totalExercises: workout.exercises.length,
            completedSets: workout.completedSets,
            totalSets: workout.totalSets,
            exerciseProgress: exerciseProgress,
            setProgress: setProgress,
          ),

          const SizedBox(height: ForgeSpacing.xl),

          Text(
            'EXERCISES',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ForgeColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: ForgeSpacing.md),

          for (var index = 0; index < workout.exercises.length; index++) ...[
            _WorkoutExerciseCard(
              exercise: workout.exercises[index],
              recommendation:
                  adaptationByExerciseCode[workout
                      .exercises[index]
                      .exerciseCode],
              exerciseNumber: index + 1,
              isResting:
                  restRemainingSeconds > 0 &&
                  restExerciseId == workout.exercises[index].id,
              onLogSet: (set) {
                onLogSet(workout.exercises[index], set);
              },
              onSkip: () {
                onSkipExercise(workout.exercises[index]);
              },
            ),

            if (index < workout.exercises.length - 1)
              const SizedBox(height: ForgeSpacing.md),
          ],

          const SizedBox(height: ForgeSpacing.xl),

          if (workout.pendingExercises > 0)
            Container(
              margin: const EdgeInsets.only(bottom: ForgeSpacing.md),
              padding: const EdgeInsets.all(ForgeSpacing.md),
              decoration: BoxDecoration(
                color: ForgeColors.surface,
                borderRadius: BorderRadius.circular(ForgeRadius.md),
                border: Border.all(color: ForgeColors.outline),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: ForgeColors.textSecondary,
                  ),
                  const SizedBox(width: ForgeSpacing.sm),
                  Expanded(
                    child: Text(
                      'Complete or skip '
                      '${workout.pendingExercises} '
                      'remaining '
                      '${workout.pendingExercises == 1 ? 'exercise' : 'exercises'} '
                      'before finishing.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: workout.pendingExercises == 0 && !isFinishing
                  ? onFinish
                  : null,
              icon: const Icon(Icons.flag_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: isFinishing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text('FINISH WORKOUT'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutProgressPanel extends StatelessWidget {
  const _WorkoutProgressPanel({
    required this.completedExercises,
    required this.totalExercises,
    required this.completedSets,
    required this.totalSets,
    required this.exerciseProgress,
    required this.setProgress,
  });

  final int completedExercises;
  final int totalExercises;
  final int completedSets;
  final int totalSets;

  final double exerciseProgress;
  final double setProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Column(
        children: [
          _ProgressRow(
            label: 'EXERCISES',
            value: '$completedExercises / $totalExercises',
            progress: exerciseProgress,
          ),

          const SizedBox(height: ForgeSpacing.lg),

          _ProgressRow(
            label: 'SETS',
            value: '$completedSets / $totalSets',
            progress: setProgress,
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ForgeColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: ForgeColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: ForgeColors.surfaceRaised,
          ),
        ),
      ],
    );
  }
}

class _RestTimerCard extends StatelessWidget {
  const _RestTimerCard({
    required this.exerciseName,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onSkip,
    required this.onAddThirtySeconds,
  });

  final String exerciseName;
  final int remainingSeconds;
  final int totalSeconds;

  final VoidCallback onSkip;
  final VoidCallback onAddThirtySeconds;

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds <= 0
        ? 0.0
        : (remainingSeconds / totalSeconds).clamp(0.0, 1.0).toDouble();

    return Container(
      decoration: const BoxDecoration(
        color: ForgeColors.surfaceRaised,
        border: Border(top: BorderSide(color: ForgeColors.outlineStrong)),
      ),
      padding: const EdgeInsets.fromLTRB(
        ForgeSpacing.lg,
        ForgeSpacing.md,
        ForgeSpacing.lg,
        ForgeSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ForgeColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ForgeRadius.sm),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: ForgeColors.warning,
                ),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESTING',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ForgeColors.warning,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exerciseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              Text(
                _formatRestTime(remainingSeconds),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: ForgeColors.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.sm),

          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: ForgeColors.warning,
              backgroundColor: ForgeColors.surfaceSoft,
            ),
          ),

          const SizedBox(height: 2),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: ForgeColors.textSecondary,
                ),
                child: const Text('SKIP'),
              ),
              TextButton.icon(
                onPressed: onAddThirtySeconds,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('+30S'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatRestTime(int seconds) {
  final minutes = seconds ~/ 60;

  final remaining = (seconds % 60).toString().padLeft(2, '0');

  return '${minutes.toString().padLeft(2, '0')}:$remaining';
}

class _WorkoutExerciseCard extends StatelessWidget {
  const _WorkoutExerciseCard({
    required this.exercise,
    required this.recommendation,
    required this.exerciseNumber,
    required this.isResting,
    required this.onLogSet,
    required this.onSkip,
  });

  final WorkoutExerciseData exercise;

  final AdaptationRecommendationData? recommendation;

  final int exerciseNumber;
  final bool isResting;

  final ValueChanged<WorkoutSetData> onLogSet;

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final reps = exercise.targetMinReps == exercise.targetMaxReps
        ? '${exercise.targetMinReps}'
        : '${exercise.targetMinReps}'
              '\u2013'
              '${exercise.targetMaxReps}';

    String? readySetId;

    for (final workoutSet in exercise.sets) {
      if (!workoutSet.isCompleted) {
        readySetId = workoutSet.id;
        break;
      }
    }

    final resolved = exercise.isCompleted || exercise.isSkipped;

    final rawGuidance = recommendation;

    final guidance =
        exercise.isPending &&
            rawGuidance != null &&
            !adaptationNeedsMoreData(rawGuidance)
        ? rawGuidance
        : null;

    return Container(
      decoration: BoxDecoration(
        color: resolved
            ? ForgeColors.surface.withValues(alpha: 0.72)
            : ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(
          color: exercise.isCompleted
              ? ForgeColors.success.withValues(alpha: 0.24)
              : isResting
              ? ForgeColors.warning.withValues(alpha: 0.32)
              : ForgeColors.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ForgeSpacing.lg,
              ForgeSpacing.lg,
              ForgeSpacing.lg,
              ForgeSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ForgeColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(ForgeRadius.sm),
                      ),
                      child: Text(
                        '$exerciseNumber',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),

                    const SizedBox(width: ForgeSpacing.md),

                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: exercise.exerciseId?.trim().isNotEmpty == true
                              ? () {
                                  showExerciseDetailSheet(
                                    context,
                                    exerciseId: exercise.exerciseId!.trim(),
                                    exerciseName: exercise.exerciseName,
                                    sets: exercise.targetSets,
                                    minReps: exercise.targetMinReps,
                                    maxReps: exercise.targetMaxReps,
                                    restSeconds: exercise.targetRestSeconds,
                                  );
                                }
                              : null,
                          borderRadius: BorderRadius.circular(ForgeRadius.md),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        exercise.exerciseName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    if (exercise.exerciseId
                                            ?.trim()
                                            .isNotEmpty ==
                                        true)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(
                                          Icons.chevron_right_rounded,
                                          size: 20,
                                          color: ForgeColors.textMuted,
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 5),

                                Text(
                                  '${exercise.targetSets} sets '
                                  '\u00d7 $reps reps '
                                  '\u2022 '
                                  '${exercise.targetRestSeconds}s rest',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: ForgeColors.textSecondary,
                                      ),
                                ),

                                if (exercise.exerciseId?.trim().isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.accessibility_new_rounded,
                                        size: 14,
                                        color: ForgeColors.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'View target muscles',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: ForgeColors.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    _ExerciseStatusBadge(
                      exercise: exercise,
                      isResting: isResting,
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (guidance != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ForgeSpacing.lg,
                0,
                ForgeSpacing.lg,
                ForgeSpacing.md,
              ),
              child: _WorkoutGuidance(recommendation: guidance),
            ),
          ],

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.all(ForgeSpacing.md),
            child: Column(
              children: [
                for (var index = 0; index < exercise.sets.length; index++) ...[
                  _WorkoutSetTile(
                    workoutSet: exercise.sets[index],
                    enabled: !exercise.isSkipped,
                    isReady: readySetId == exercise.sets[index].id,
                    isResting: isResting,
                    onTap: () {
                      onLogSet(exercise.sets[index]);
                    },
                  ),

                  if (index < exercise.sets.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),

          if (exercise.isPending) ...[
            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                ForgeSpacing.md,
                ForgeSpacing.xs,
                ForgeSpacing.md,
                ForgeSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onSkip,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: const Text('Skip exercise'),
                  style: TextButton.styleFrom(
                    foregroundColor: ForgeColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkoutGuidance extends StatelessWidget {
  const _WorkoutGuidance({required this.recommendation});

  final AdaptationRecommendationData recommendation;

  @override
  Widget build(BuildContext context) {
    final presentation = adaptationPresentationFor(recommendation);

    final suggestion = adaptationWorkoutSuggestionFor(recommendation);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ForgeSpacing.md,
        vertical: ForgeSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        border: Border.all(color: presentation.color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(presentation.icon, size: 18, color: presentation.color),
          ),

          const SizedBox(width: ForgeSpacing.sm),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FORGE GUIDANCE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ForgeColors.textMuted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),

                const SizedBox(height: 3),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        presentation.label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: presentation.color,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),

                    Text(
                      recommendation.confidence.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ForgeColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                if (suggestion != null) ...[
                  const SizedBox(height: 4),

                  Text(
                    suggestion,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ForgeColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseStatusBadge extends StatelessWidget {
  const _ExerciseStatusBadge({required this.exercise, required this.isResting});

  final WorkoutExerciseData exercise;
  final bool isResting;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    late final IconData? icon;

    if (exercise.isCompleted) {
      label = 'DONE';
      color = ForgeColors.success;
      icon = Icons.check_rounded;
    } else if (exercise.isSkipped) {
      label = 'SKIPPED';
      color = ForgeColors.textMuted;
      icon = Icons.skip_next_rounded;
    } else if (isResting) {
      label = 'REST';
      color = ForgeColors.warning;
      icon = Icons.timer_outlined;
    } else {
      label = '${exercise.completedSetCount}/${exercise.sets.length}';
      color = ForgeColors.primary;
      icon = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _WorkoutSetTile extends StatelessWidget {
  const _WorkoutSetTile({
    required this.workoutSet,
    required this.enabled,
    required this.isReady,
    required this.isResting,
    required this.onTap,
  });

  final WorkoutSetData workoutSet;
  final bool enabled;
  final bool isReady;
  final bool isResting;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = <String>[];

    if (workoutSet.weightKg != null) {
      details.add('${_formatNumber(workoutSet.weightKg!)} kg');
    }

    if (workoutSet.actualReps != null) {
      details.add('${workoutSet.actualReps} reps');
    }

    if (workoutSet.rpe != null) {
      details.add('RPE ${_formatNumber(workoutSet.rpe!)}');
    }

    final waitingForRest = isReady && isResting;

    final canOpen =
        enabled && (workoutSet.isCompleted || (isReady && !isResting));

    final Color borderColor;

    if (workoutSet.isCompleted) {
      borderColor = ForgeColors.success.withValues(alpha: 0.24);
    } else if (waitingForRest) {
      borderColor = ForgeColors.warning.withValues(alpha: 0.28);
    } else if (isReady) {
      borderColor = ForgeColors.primary.withValues(alpha: 0.40);
    } else {
      borderColor = ForgeColors.outline;
    }

    return Material(
      color: workoutSet.isCompleted
          ? ForgeColors.success.withValues(alpha: 0.05)
          : isReady
          ? ForgeColors.primary.withValues(alpha: 0.06)
          : ForgeColors.surfaceRaised,
      borderRadius: BorderRadius.circular(ForgeRadius.md),
      child: InkWell(
        onTap: canOpen ? onTap : null,
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ForgeSpacing.md,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ForgeRadius.md),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: workoutSet.isCompleted
                      ? ForgeColors.success.withValues(alpha: 0.12)
                      : ForgeColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: workoutSet.isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: ForgeColors.success,
                      )
                    : Text(
                        '${workoutSet.setNumber}',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SET ${workoutSet.setNumber}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: workoutSet.isCompleted
                            ? ForgeColors.textSecondary
                            : ForgeColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      workoutSet.isCompleted
                          ? details.isEmpty
                                ? 'Completed'
                                : details.join(' \u2022 ')
                          : waitingForRest
                          ? 'Rest before this set'
                          : isReady
                          ? 'Ready to log'
                          : 'Complete previous set first',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: workoutSet.isCompleted
                            ? ForgeColors.textSecondary
                            : null,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              if (workoutSet.isCompleted)
                const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: ForgeColors.textMuted,
                )
              else if (waitingForRest)
                _SetStateBadge(
                  label: 'REST',
                  color: ForgeColors.warning,
                  icon: Icons.timer_outlined,
                )
              else if (isReady)
                const _SetStateBadge(label: 'READY', color: ForgeColors.primary)
              else
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: ForgeColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetStateBadge extends StatelessWidget {
  const _SetStateBadge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SetLogSheet extends StatefulWidget {
  const _SetLogSheet({
    required this.exercise,
    required this.workoutSet,
    required this.previousSet,
  });

  final WorkoutExerciseData exercise;
  final WorkoutSetData workoutSet;
  final WorkoutSetData? previousSet;

  @override
  State<_SetLogSheet> createState() => _SetLogSheetState();
}

class _SetLogSheetState extends State<_SetLogSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _weightController;

  late final TextEditingController _repsController;

  late final TextEditingController _rpeController;

  @override
  void initState() {
    super.initState();

    final suggestedWeight =
        widget.workoutSet.weightKg ?? widget.previousSet?.weightKg;

    final suggestedReps =
        widget.workoutSet.actualReps ??
        widget.previousSet?.actualReps ??
        widget.exercise.targetMaxReps;

    _weightController = TextEditingController(
      text: suggestedWeight == null ? '' : _formatNumber(suggestedWeight),
    );

    _repsController = TextEditingController(text: suggestedReps.toString());

    _rpeController = TextEditingController(
      text: widget.workoutSet.rpe == null
          ? ''
          : _formatNumber(widget.workoutSet.rpe!),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _rpeController.dispose();

    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final weightText = _weightController.text.trim();

    final rpeText = _rpeController.text.trim();

    FocusScope.of(context).unfocus();

    Navigator.of(context).pop(
      _SetLogResult(
        actualReps: int.parse(_repsController.text.trim()),
        weightKg: weightText.isEmpty ? null : double.parse(weightText),
        rpe: rpeText.isEmpty ? null : double.parse(rpeText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final targetReps =
        widget.exercise.targetMinReps == widget.exercise.targetMaxReps
        ? '${widget.exercise.targetMinReps}'
        : '${widget.exercise.targetMinReps}'
              '\u2013'
              '${widget.exercise.targetMaxReps}';

    final isEditing = widget.workoutSet.isCompleted;

    return Container(
      decoration: const BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ForgeRadius.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ForgeSpacing.xl,
            ForgeSpacing.sm,
            ForgeSpacing.xl,
            ForgeSpacing.xl + bottomInset,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SetLogHeader(
                  exerciseName: widget.exercise.exerciseName,
                  setNumber: widget.workoutSet.setNumber,
                  isEditing: isEditing,
                ),

                const SizedBox(height: ForgeSpacing.lg),

                _SetTargetPanel(
                  targetReps: targetReps,
                  restSeconds: widget.exercise.targetRestSeconds,
                ),

                if (!isEditing && widget.previousSet != null) ...[
                  const SizedBox(height: ForgeSpacing.md),
                  _PreviousSetPanel(set: widget.previousSet!),
                ],

                const SizedBox(height: ForgeSpacing.xl),

                Text(
                  'PERFORMANCE',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ForgeColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),

                const SizedBox(height: ForgeSpacing.md),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SetLogField(
                        controller: _weightController,
                        label: 'WEIGHT',
                        suffixText: 'kg',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final input = value?.trim() ?? '';

                          if (input.isEmpty) {
                            return null;
                          }

                          final weight = double.tryParse(input);

                          if (weight == null || weight < 0) {
                            return 'Invalid';
                          }

                          return null;
                        },
                      ),
                    ),

                    const SizedBox(width: ForgeSpacing.md),

                    Expanded(
                      child: _SetLogField(
                        controller: _repsController,
                        label: 'REPS',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final reps = int.tryParse(value?.trim() ?? '');

                          if (reps == null || reps < 0) {
                            return 'Invalid';
                          }

                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: ForgeSpacing.lg),

                _SetLogField(
                  controller: _rpeController,
                  label: 'RPE',
                  hintText: 'Optional',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    _submit();
                  },
                  validator: (value) {
                    final input = value?.trim() ?? '';

                    if (input.isEmpty) {
                      return null;
                    }

                    final rpe = double.tryParse(input);

                    if (rpe == null || rpe < 1 || rpe > 10) {
                      return 'RPE must be 1\u201310';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    const Icon(
                      Icons.speed_rounded,
                      size: 16,
                      color: ForgeColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Rate how hard the set felt '
                        'from 1 to 10.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: ForgeColors.textMuted),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: ForgeSpacing.xl),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: Icon(
                      isEditing ? Icons.edit_rounded : Icons.check_rounded,
                    ),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(isEditing ? 'UPDATE SET' : 'COMPLETE SET'),
                    ),
                  ),
                ),

                const SizedBox(height: ForgeSpacing.sm),

                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();

                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetLogHeader extends StatelessWidget {
  const _SetLogHeader({
    required this.exerciseName,
    required this.setNumber,
    required this.isEditing,
  });

  final String exerciseName;
  final int setNumber;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isEditing ? 'EDIT SET' : 'LOG SET',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: ForgeColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ForgeColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'SET $setNumber',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ForgeColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          exerciseName,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _SetTargetPanel extends StatelessWidget {
  const _SetTargetPanel({required this.targetReps, required this.restSeconds});

  final String targetReps;
  final int restSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        color: ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SetTargetMetric(
              label: 'TARGET',
              value: '$targetReps reps',
              icon: Icons.repeat_rounded,
            ),
          ),

          Container(width: 1, height: 36, color: ForgeColors.outline),

          Expanded(
            child: _SetTargetMetric(
              label: 'REST',
              value: '${restSeconds}s',
              icon: Icons.timer_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetTargetMetric extends StatelessWidget {
  const _SetTargetMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: ForgeColors.textSecondary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ForgeColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviousSetPanel extends StatelessWidget {
  const _PreviousSetPanel({required this.set});

  final WorkoutSetData set;

  @override
  Widget build(BuildContext context) {
    final values = <String>[];

    if (set.weightKg != null) {
      values.add('${_formatNumber(set.weightKg!)} kg');
    }

    if (set.actualReps != null) {
      values.add('${set.actualReps} reps');
    }

    if (set.rpe != null) {
      values.add('RPE ${_formatNumber(set.rpe!)}');
    }

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        color: ForgeColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        border: Border.all(color: ForgeColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ForgeColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(ForgeRadius.sm),
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 19,
              color: ForgeColors.primary,
            ),
          ),

          const SizedBox(width: ForgeSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREVIOUS SET',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ForgeColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  values.isEmpty ? 'Completed' : values.join(' \u2022 '),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetLogField extends StatelessWidget {
  const _SetLogField({
    required this.controller,
    required this.label,
    required this.keyboardType,
    required this.textInputAction,
    required this.validator,
    this.suffixText,
    this.hintText,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? suffixText;
  final String? hintText;

  final String? Function(String?) validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixText: suffixText,
        filled: true,
        fillColor: ForgeColors.surfaceRaised,
      ),
      validator: validator,
    );
  }
}

class _SetLogResult {
  const _SetLogResult({
    required this.actualReps,
    required this.weightKg,
    required this.rpe,
  });

  final int actualReps;
  final double? weightKg;
  final double? rpe;
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toString();
}
