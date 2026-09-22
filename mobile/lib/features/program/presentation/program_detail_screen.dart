import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../../../core/theme/forge_theme.dart';
import '../../exercise/presentation/exercise_detail_sheet.dart';
import '../../workout/data/workout_models.dart';
import '../../workout/data/workout_repository.dart';
import '../../workout/presentation/workout_controller.dart';
import '../../workout/presentation/workout_session_screen.dart';
import '../data/program_models.dart';

class ProgramDetailScreen extends ConsumerStatefulWidget {
  const ProgramDetailScreen({required this.program, super.key});

  final ProgramDetailData program;

  @override
  ConsumerState<ProgramDetailScreen> createState() =>
      _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends ConsumerState<ProgramDetailScreen> {
  String? _startingDayId;

  Future<void> _openWorkout() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return const WorkoutSessionScreen();
        },
      ),
    );
  }

  Future<void> _startWorkout(ProgramDayData day) async {
    if (_startingDayId != null) {
      return;
    }

    setState(() {
      _startingDayId = day.id;
    });

    try {
      await ref.read(workoutControllerProvider.notifier).startWorkout(day.id);

      if (!mounted) {
        return;
      }

      await _openWorkout();
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
        const SnackBar(content: Text('Could not start this workout.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _startingDayId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;

    final days = [...program.days]
      ..sort((left, right) => left.dayOrder.compareTo(right.dayOrder));

    final workoutState = ref.watch(workoutControllerProvider);

    final currentWorkout = workoutState.value?.currentWorkout;

    return Scaffold(
      appBar: AppBar(title: const Text('TRAINING PROGRAM')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            ForgeSpacing.xl,
            ForgeSpacing.lg,
            ForgeSpacing.xl,
            ForgeSpacing.xxl,
          ),
          children: [
            _ProgramHeader(program: program),

            const SizedBox(height: ForgeSpacing.xxl),

            _SectionHeader(
              title: 'WEEKLY PLAN',
              trailing: '${program.days.length} DAYS',
            ),

            const SizedBox(height: ForgeSpacing.md),

            for (var index = 0; index < days.length; index++) ...[
              _ProgramDayCard(
                day: days[index],
                currentWorkout: currentWorkout,
                isStarting: _startingDayId == days[index].id,
                startBlocked: _startingDayId != null,
                onStart: () {
                  _startWorkout(days[index]);
                },
                onResume: _openWorkout,
              ),
              if (index < days.length - 1)
                const SizedBox(height: ForgeSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgramHeader extends StatelessWidget {
  const _ProgramHeader({required this.program});

  final ProgramDetailData program;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.xl),
      decoration: BoxDecoration(
        color: ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _goalLabel(program.goal).toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: ForgeColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      program.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ForgeColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'V${program.versionNumber}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ForgeColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.xl),

          Row(
            children: [
              Expanded(
                child: _HeaderMetric(
                  value: '${program.days.length}',
                  label: 'DAYS / WEEK',
                ),
              ),

              Container(width: 1, height: 44, color: ForgeColors.outline),

              Expanded(
                child: _HeaderMetric(
                  value: '${program.totalExercises}',
                  label: 'EXERCISES',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ForgeColors.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }
}

class _ProgramDayCard extends StatelessWidget {
  const _ProgramDayCard({
    required this.day,
    required this.currentWorkout,
    required this.isStarting,
    required this.startBlocked,
    required this.onStart,
    required this.onResume,
  });

  final ProgramDayData day;

  final WorkoutSessionData? currentWorkout;

  final bool isStarting;
  final bool startBlocked;

  final VoidCallback onStart;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final isCurrentWorkout = currentWorkout?.programDayId == day.id;

    final anotherWorkoutIsActive = currentWorkout != null && !isCurrentWorkout;

    final totalSets = day.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets,
    );

    return Container(
      decoration: BoxDecoration(
        color: isCurrentWorkout
            ? ForgeColors.primary.withValues(alpha: 0.05)
            : ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(
          color: isCurrentWorkout
              ? ForgeColors.primary.withValues(alpha: 0.24)
              : ForgeColors.outline,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isCurrentWorkout || day.dayOrder == 1,
          tilePadding: const EdgeInsets.fromLTRB(
            ForgeSpacing.lg,
            ForgeSpacing.md,
            ForgeSpacing.lg,
            ForgeSpacing.md,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            ForgeSpacing.lg,
            0,
            ForgeSpacing.lg,
            ForgeSpacing.lg,
          ),
          iconColor: isCurrentWorkout
              ? ForgeColors.primary
              : ForgeColors.textSecondary,
          collapsedIconColor: ForgeColors.textMuted,
          title: _DayHeader(day: day, isCurrentWorkout: isCurrentWorkout),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              '${weekdayLabel(day.dayOfWeek)}'
              ' \u2022 '
              '${day.estimatedDurationMinutes} min'
              ' \u2022 '
              '${day.exercises.length} exercises'
              ' \u2022 '
              '$totalSets sets',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: ForgeColors.textSecondary),
            ),
          ),
          children: [
            const Divider(color: ForgeColors.outline),

            const SizedBox(height: 4),

            for (var index = 0; index < day.exercises.length; index++) ...[
              _ExerciseRow(exercise: day.exercises[index]),
              if (index < day.exercises.length - 1)
                const Divider(height: 1, color: ForgeColors.outline),
            ],

            const SizedBox(height: ForgeSpacing.lg),

            if (isCurrentWorkout)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: Text('RESUME WORKOUT'),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: anotherWorkoutIsActive || startBlocked
                      ? null
                      : onStart,
                  icon: isStarting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(
                      isStarting
                          ? 'STARTING...'
                          : anotherWorkoutIsActive
                          ? 'WORKOUT ACTIVE'
                          : 'START WORKOUT',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.isCurrentWorkout});

  final ProgramDayData day;
  final bool isCurrentWorkout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrentWorkout
                ? ForgeColors.primary.withValues(alpha: 0.10)
                : ForgeColors.surfaceRaised,
            borderRadius: BorderRadius.circular(ForgeRadius.sm),
          ),
          child: Text(
            _shortWeekday(day.dayOfWeek),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isCurrentWorkout
                  ? ForgeColors.primary
                  : ForgeColors.textSecondary,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ),

        const SizedBox(width: ForgeSpacing.md),

        Expanded(
          child: Text(
            day.name,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),

        if (isCurrentWorkout)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: _CurrentBadge(),
          ),
      ],
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ForgeColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        'IN PROGRESS',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ForgeColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});

  final ProgramExerciseData exercise;

  @override
  Widget build(BuildContext context) {
    final reps = exercise.minReps == exercise.maxReps
        ? '${exercise.minReps}'
        : '${exercise.minReps}'
              '\u2013'
              '${exercise.maxReps}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        onTap: () {
          showExerciseDetailSheet(
            context,
            exerciseId: exercise.exerciseId,
            exerciseName: exercise.exerciseName,
            sets: exercise.sets,
            minReps: exercise.minReps,
            maxReps: exercise.maxReps,
            restSeconds: exercise.restSeconds,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ForgeSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ForgeColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(ForgeRadius.sm),
                  border: Border.all(color: ForgeColors.outline),
                ),
                child: Text(
                  exercise.exerciseOrder.toString().padLeft(2, '0'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ForgeColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.exerciseName,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      '${exercise.sets} \u00d7 '
                      '$reps reps'
                      ' \u2022 '
                      '${exercise.restSeconds}s rest',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ForgeColors.textSecondary),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'View target muscles',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ForgeColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: ForgeColors.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
        const Spacer(),
        Text(
          trailing,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ForgeColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _goalLabel(String value) {
  switch (value) {
    case 'muscle_gain':
      return 'Muscle Gain';
    case 'strength':
      return 'Strength';
    case 'fat_loss':
      return 'Fat Loss';
    case 'general_fitness':
      return 'General Fitness';
    case 'hybrid':
      return 'Hybrid';
    default:
      return value;
  }
}

String _shortWeekday(int value) {
  final label = weekdayLabel(value);

  if (label.length <= 3) {
    return label.toUpperCase();
  }

  return label.substring(0, 3).toUpperCase();
}
