import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../../../core/theme/forge_theme.dart';
import '../../exercise/presentation/exercise_library_screen.dart';
import '../../program/data/program_models.dart';
import '../../program/presentation/program_controller.dart';
import '../../program/presentation/program_detail_screen.dart';
import '../../workout/data/workout_models.dart';
import '../../workout/presentation/workout_controller.dart';
import '../../workout/presentation/workout_session_screen.dart';

class TrainScreen extends ConsumerWidget {
  const TrainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(programControllerProvider);

    final workoutAsync = ref.watch(workoutControllerProvider);

    if (programAsync.isLoading || workoutAsync.isLoading) {
      return const Scaffold(
        appBar: _TrainAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (programAsync.hasError || workoutAsync.hasError) {
      return Scaffold(
        appBar: const _TrainAppBar(),
        body: _TrainErrorState(
          onRetry: () async {
            await Future.wait([
              ref.read(programControllerProvider.notifier).refresh(),
              ref.read(workoutControllerProvider.notifier).refresh(),
            ]);
          },
        ),
      );
    }

    final program = programAsync.value?.currentProgram;

    final workout = workoutAsync.value?.currentWorkout;

    return Scaffold(
      appBar: const _TrainAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(programControllerProvider.notifier).refresh(),
            ref.read(workoutControllerProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            ForgeSpacing.xl,
            ForgeSpacing.lg,
            ForgeSpacing.xl,
            ForgeSpacing.xxl,
          ),
          children: [
            Text(
              'TRAIN',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.4),
            ),
            const SizedBox(height: 6),
            Text(
              'Your weekly training plan.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: ForgeColors.textSecondary),
            ),

            const SizedBox(height: ForgeSpacing.xl),

            if (program?.isOutdated ?? false) ...[
              const _OutdatedProgramBanner(),
              const SizedBox(height: ForgeSpacing.lg),
            ],

            if (workout != null) ...[
              _ActiveWorkoutCard(
                workout: workout,
                onResume: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) {
                        return const WorkoutSessionScreen();
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: ForgeSpacing.xl),
            ],

            _ExerciseLibraryEntryCard(
              onOpen: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) {
                      return const ExerciseLibraryScreen();
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: ForgeSpacing.xl),

            if (program != null) ...[
              _ProgramOverviewCard(
                program: program,
                onOpen: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) {
                        return ProgramDetailScreen(program: program);
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: ForgeSpacing.xxl),

              _SectionHeader(
                title: 'WEEKLY SCHEDULE',
                trailing: '${program.days.length} DAYS',
              ),

              const SizedBox(height: ForgeSpacing.md),

              _WeeklySchedule(
                program: program,
                currentWorkout: workout,
                onOpenProgram: (day) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) {
                        return ProgramDetailScreen(
                          program: program,
                          initialDayId: day.id,
                        );
                      },
                    ),
                  );
                },
              ),
            ] else
              const _NoProgramState(),
          ],
        ),
      ),
    );
  }
}

class _TrainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _TrainAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(toolbarHeight: 0);
  }

  @override
  Size get preferredSize => Size.zero;
}

class _ActiveWorkoutCard extends StatelessWidget {
  const _ActiveWorkoutCard({required this.workout, required this.onResume});

  final WorkoutSessionData workout;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final progress = workout.totalSets == 0
        ? 0.0
        : workout.completedSets / workout.totalSets;

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ForgeColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(ForgeRadius.sm),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: ForgeColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: ForgeSpacing.md),
              Expanded(
                child: Text(
                  'WORKOUT IN PROGRESS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ForgeColors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.lg),

          Text(
            workout.dayName,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Text(
                '${workout.completedSets}'
                ' / '
                '${workout.totalSets} sets',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: ForgeColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: ForgeColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.sm),

          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: ForgeColors.surfaceSoft,
              color: ForgeColors.primary,
            ),
          ),

          const SizedBox(height: ForgeSpacing.lg),

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
          ),
        ],
      ),
    );
  }
}

class _ProgramOverviewCard extends StatelessWidget {
  const _ProgramOverviewCard({required this.program, required this.onOpen});

  final ProgramDetailData program;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CURRENT PROGRAM',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: ForgeColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: ForgeColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'V${program.versionNumber}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ForgeColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.md),

          Text(
            program.name,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 5),

          Text(
            _goalLabel(program.goal),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: ForgeColors.textSecondary),
          ),

          const SizedBox(height: ForgeSpacing.xl),

          Row(
            children: [
              Expanded(
                child: _ProgramMetric(
                  value: '${program.days.length}',
                  label: 'DAYS / WEEK',
                ),
              ),
              Container(width: 1, height: 40, color: ForgeColors.outline),
              Expanded(
                child: _ProgramMetric(
                  value: '${program.totalExercises}',
                  label: 'EXERCISES',
                ),
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.lg),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('VIEW FULL PROGRAM'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramMetric extends StatelessWidget {
  const _ProgramMetric({required this.value, required this.label});

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
        const SizedBox(height: 2),
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

class _WeeklySchedule extends StatelessWidget {
  const _WeeklySchedule({
    required this.program,
    required this.currentWorkout,
    required this.onOpenProgram,
  });

  final ProgramDetailData program;
  final WorkoutSessionData? currentWorkout;
  final ValueChanged<ProgramDayData> onOpenProgram;

  @override
  Widget build(BuildContext context) {
    final days = [...program.days]
      ..sort((left, right) => left.dayOrder.compareTo(right.dayOrder));

    return Column(
      children: [
        for (var index = 0; index < days.length; index++) ...[
          _TrainDayCard(
            day: days[index],
            isCurrent: currentWorkout?.programDayId == days[index].id,
            onTap: () {
              onOpenProgram(days[index]);
            },
          ),
          if (index < days.length - 1) const SizedBox(height: ForgeSpacing.sm),
        ],
      ],
    );
  }
}

class _TrainDayCard extends StatelessWidget {
  const _TrainDayCard({
    required this.day,
    required this.isCurrent,
    required this.onTap,
  });

  final ProgramDayData day;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isCurrent
          ? ForgeColors.primary.withValues(alpha: 0.06)
          : ForgeColors.surface,
      borderRadius: BorderRadius.circular(ForgeRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        child: Container(
          padding: const EdgeInsets.all(ForgeSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ForgeRadius.md),
            border: Border.all(
              color: isCurrent
                  ? ForgeColors.primary.withValues(alpha: 0.22)
                  : ForgeColors.outline,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? ForgeColors.primary.withValues(alpha: 0.10)
                      : ForgeColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(ForgeRadius.sm),
                ),
                child: Text(
                  _shortWeekday(day.dayOfWeek),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isCurrent
                        ? ForgeColors.primary
                        : ForgeColors.textSecondary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            day.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isCurrent) const _InProgressBadge(),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${weekdayLabel(day.dayOfWeek)}'
                      ' \u2022 '
                      '${day.estimatedDurationMinutes} min'
                      ' \u2022 '
                      '${day.exercises.length} exercises',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ForgeColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                color: ForgeColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InProgressBadge extends StatelessWidget {
  const _InProgressBadge();

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

class _OutdatedProgramBanner extends StatelessWidget {
  const _OutdatedProgramBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        color: ForgeColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        border: Border.all(color: ForgeColors.warning.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.update_rounded,
            color: ForgeColors.warning,
            size: 21,
          ),
          const SizedBox(width: ForgeSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Training setup changed',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'This program uses an older '
                  'training setup. Regenerate '
                  'it from Home to apply your '
                  'latest settings.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: ForgeColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoProgramState extends StatelessWidget {
  const _NoProgramState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ForgeSpacing.xl,
        vertical: ForgeSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            size: 42,
            color: ForgeColors.textMuted,
          ),
          const SizedBox(height: ForgeSpacing.md),
          Text(
            'No active program',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            'Generate a training program '
            'from Home to see your weekly '
            'schedule here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: ForgeColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TrainErrorState extends StatelessWidget {
  const _TrainErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ForgeSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: ForgeColors.textMuted,
            ),
            const SizedBox(height: ForgeSpacing.lg),
            Text(
              'Could not load training data',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: ForgeColors.textSecondary),
            ),
            const SizedBox(height: ForgeSpacing.xl),
            FilledButton.icon(
              onPressed: () {
                onRetry();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('RETRY'),
            ),
          ],
        ),
      ),
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

class _ExerciseLibraryEntryCard extends StatelessWidget {
  const _ExerciseLibraryEntryCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ForgeColors.surface,
      borderRadius: BorderRadius.circular(ForgeRadius.md),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ForgeSpacing.lg,
            vertical: ForgeSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ForgeRadius.md),
            border: Border.all(color: ForgeColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ForgeColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(ForgeRadius.sm),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: ForgeColors.primary,
                  size: 21,
                ),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXERCISE LIBRARY',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Browse exercises by '
                      'primary muscle group.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ForgeColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: ForgeSpacing.sm),

              const Icon(
                Icons.chevron_right_rounded,
                color: ForgeColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
