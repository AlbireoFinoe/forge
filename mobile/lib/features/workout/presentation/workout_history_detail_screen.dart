import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../../../core/theme/forge_theme.dart';
import '../data/workout_models.dart';
import 'workout_controller.dart';

class WorkoutHistoryDetailScreen extends ConsumerWidget {
  const WorkoutHistoryDetailScreen({
    required this.workoutId,
    this.title = 'WORKOUT SUMMARY',
    super.key,
  });

  final String workoutId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutDetailProvider(workoutId));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: workout.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return _DetailErrorState(
            onRetry: () {
              ref.invalidate(workoutDetailProvider(workoutId));
            },
          );
        },
        data: (session) {
          return _WorkoutHistoryContent(workout: session);
        },
      ),
    );
  }
}

class _WorkoutHistoryContent extends StatelessWidget {
  const _WorkoutHistoryContent({required this.workout});

  final WorkoutSessionData workout;

  @override
  Widget build(BuildContext context) {
    final completedExercises = workout.exercises
        .where((exercise) => exercise.isCompleted)
        .length;

    final skippedExercises = workout.exercises
        .where((exercise) => exercise.isSkipped)
        .length;

    final completedAt = workout.completedAt;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        ForgeSpacing.xl,
        ForgeSpacing.lg,
        ForgeSpacing.xl,
        ForgeSpacing.xxl +
            MediaQuery.paddingOf(context).bottom +
            ForgeSpacing.xl,
      ),
      children: [
        _WorkoutSummaryHeader(
          workout: workout,
          completedExercises: completedExercises,
          skippedExercises: skippedExercises,
        ),

        const SizedBox(height: ForgeSpacing.xxl),

        Row(
          children: [
            Text(
              'EXERCISES',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
            const Spacer(),
            Text(
              '${workout.exercises.length} TOTAL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ForgeColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: ForgeSpacing.md),

        for (var index = 0; index < workout.exercises.length; index++) ...[
          _HistoryExerciseCard(
            exercise: workout.exercises[index],
            number: index + 1,
          ),

          if (index < workout.exercises.length - 1)
            const SizedBox(height: ForgeSpacing.md),
        ],

        if (completedAt != null) ...[
          const SizedBox(height: ForgeSpacing.xxl),

          _SessionTimingCard(
            startedAt: workout.startedAt,
            completedAt: completedAt,
          ),
        ],
      ],
    );
  }
}

class _WorkoutSummaryHeader extends StatelessWidget {
  const _WorkoutSummaryHeader({
    required this.workout,
    required this.completedExercises,
    required this.skippedExercises,
  });

  final WorkoutSessionData workout;
  final int completedExercises;
  final int skippedExercises;

  @override
  Widget build(BuildContext context) {
    final completedAt = workout.completedAt;

    final duration = completedAt?.difference(workout.startedAt);

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.xl),
      decoration: BoxDecoration(
        color: ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(
          color: workout.status == 'completed'
              ? ForgeColors.success.withValues(alpha: 0.18)
              : ForgeColors.outline,
        ),
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
                      workout.dayName,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '${weekdayLabel(workout.dayOfWeek)}'
                      ' \u2022 '
                      'Program v${workout.programVersionNumber}',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: ForgeColors.textSecondary),
                    ),
                  ],
                ),
              ),

              if (workout.status == 'completed') const _CompletedBadge(),
            ],
          ),

          const SizedBox(height: ForgeSpacing.xl),

          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  value: duration == null
                      ? '--'
                      : _formatCompactDuration(duration),
                  label: 'DURATION',
                ),
              ),

              const _MetricDivider(),

              Expanded(
                child: _SummaryMetric(
                  value:
                      '${workout.completedSets}'
                      ' / '
                      '${workout.totalSets}',
                  label: 'SETS',
                ),
              ),

              const _MetricDivider(),

              Expanded(
                child: _SummaryMetric(
                  value:
                      '$completedExercises'
                      ' / '
                      '${workout.exercises.length}',
                  label: 'EXERCISES',
                ),
              ),
            ],
          ),

          if (skippedExercises > 0) ...[
            const SizedBox(height: ForgeSpacing.lg),

            Container(
              padding: const EdgeInsets.all(ForgeSpacing.md),
              decoration: BoxDecoration(
                color: ForgeColors.surface,
                borderRadius: BorderRadius.circular(ForgeRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.skip_next_rounded,
                    size: 19,
                    color: ForgeColors.textMuted,
                  ),
                  const SizedBox(width: ForgeSpacing.sm),
                  Text(
                    '$skippedExercises '
                    '${skippedExercises == 1 ? 'exercise' : 'exercises'} '
                    'skipped',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: ForgeColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
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

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: ForgeColors.outline);
  }
}

class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ForgeColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        'COMPLETED',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ForgeColors.success,
          fontWeight: FontWeight.w800,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _HistoryExerciseCard extends StatelessWidget {
  const _HistoryExerciseCard({required this.exercise, required this.number});

  final WorkoutExerciseData exercise;
  final int number;

  @override
  Widget build(BuildContext context) {
    final completedSets = exercise.sets.where((set) => set.isCompleted).length;

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(
          color: exercise.isCompleted
              ? ForgeColors.success.withValues(alpha: 0.15)
              : ForgeColors.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ForgeColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(ForgeRadius.sm),
                ),
                child: Text(
                  number.toString().padLeft(2, '0'),
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
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      exercise.isSkipped
                          ? 'Exercise skipped'
                          : '$completedSets / '
                                '${exercise.sets.length} sets completed',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ForgeColors.textSecondary),
                    ),
                  ],
                ),
              ),

              _ExerciseStatusBadge(exercise: exercise),
            ],
          ),

          if (exercise.isSkipped) ...[
            const SizedBox(height: ForgeSpacing.lg),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ForgeSpacing.md),
              decoration: BoxDecoration(
                color: ForgeColors.surfaceRaised,
                borderRadius: BorderRadius.circular(ForgeRadius.md),
              ),
              child: Text(
                'This exercise was skipped '
                'during the session.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: ForgeColors.textMuted),
              ),
            ),
          ] else ...[
            const SizedBox(height: ForgeSpacing.lg),

            for (var index = 0; index < exercise.sets.length; index++) ...[
              _HistorySetRow(workoutSet: exercise.sets[index]),

              if (index < exercise.sets.length - 1)
                const SizedBox(height: ForgeSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}

class _ExerciseStatusBadge extends StatelessWidget {
  const _ExerciseStatusBadge({required this.exercise});

  final WorkoutExerciseData exercise;

  @override
  Widget build(BuildContext context) {
    final label = exercise.isSkipped
        ? 'SKIPPED'
        : exercise.isCompleted
        ? 'DONE'
        : exercise.status.toUpperCase();

    final color = exercise.isCompleted
        ? ForgeColors.success
        : ForgeColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w800, fontSize: 9),
      ),
    );
  }
}

class _HistorySetRow extends StatelessWidget {
  const _HistorySetRow({required this.workoutSet});

  final WorkoutSetData workoutSet;

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

    final completed = workoutSet.isCompleted;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ForgeSpacing.md,
        vertical: ForgeSpacing.md,
      ),
      decoration: BoxDecoration(
        color: completed
            ? ForgeColors.success.withValues(alpha: 0.04)
            : ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        border: Border.all(
          color: completed
              ? ForgeColors.success.withValues(alpha: 0.12)
              : ForgeColors.outline,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              'SET ${workoutSet.setNumber}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: completed
                    ? ForgeColors.textSecondary
                    : ForgeColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              completed
                  ? details.isEmpty
                        ? 'Completed'
                        : details.join(' \u2022 ')
                  : 'Not completed',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: completed ? FontWeight.w600 : FontWeight.w400,
                color: completed
                    ? ForgeColors.textPrimary
                    : ForgeColors.textMuted,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Icon(
            completed ? Icons.check_rounded : Icons.radio_button_unchecked,
            size: 19,
            color: completed ? ForgeColors.success : ForgeColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _SessionTimingCard extends StatelessWidget {
  const _SessionTimingCard({
    required this.startedAt,
    required this.completedAt,
  });

  final DateTime startedAt;
  final DateTime completedAt;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SESSION TIMING',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ForgeColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),

          const SizedBox(height: ForgeSpacing.lg),

          _TimingRow(label: 'Started', value: _formatDateTime(startedAt)),

          const SizedBox(height: ForgeSpacing.md),

          _TimingRow(label: 'Completed', value: _formatDateTime(completedAt)),

          const SizedBox(height: ForgeSpacing.md),

          _TimingRow(
            label: 'Duration',
            value: _formatDuration(startedAt, completedAt),
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _TimingRow extends StatelessWidget {
  const _TimingRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: ForgeColors.textMuted),
        ),
        const Spacer(),
        Text(
          value,
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: highlight ? ForgeColors.primary : ForgeColors.textPrimary,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.onRetry});

  final VoidCallback onRetry;

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
              'Could not load workout',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection '
              'and try again.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: ForgeColors.textSecondary),
            ),
            const SizedBox(height: ForgeSpacing.xl),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final hour = local.hour.toString().padLeft(2, '0');

  final minute = local.minute.toString().padLeft(2, '0');

  return '${local.day} '
      '${months[local.month - 1]} '
      '${local.year}'
      ' \u2022 '
      '$hour:$minute';
}

String _formatDuration(DateTime startedAt, DateTime completedAt) {
  return _formatCompactDuration(completedAt.difference(startedAt));
}

String _formatCompactDuration(Duration duration) {
  final hours = duration.inHours;

  final minutes = duration.inMinutes.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }

  return '${duration.inMinutes} min';
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toString();
}
