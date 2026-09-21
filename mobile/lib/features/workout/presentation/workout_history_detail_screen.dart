import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../data/workout_models.dart';
import 'workout_controller.dart';

class WorkoutHistoryDetailScreen extends ConsumerWidget {
  const WorkoutHistoryDetailScreen({
    required this.workoutId,
    this.title = 'Workout Detail',
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
                      ref.invalidate(workoutDetailProvider(workoutId));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
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

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.dayName,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${weekdayLabel(workout.dayOfWeek)} • '
                  'Program v${workout.programVersionNumber}',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text('$completedExercises completed'),
                    ),
                    if (skippedExercises > 0)
                      Chip(
                        avatar: const Icon(Icons.skip_next, size: 18),
                        label: Text('$skippedExercises skipped'),
                      ),
                    Chip(
                      avatar: const Icon(Icons.fitness_center, size: 18),
                      label: Text(
                        '${workout.completedSets}/${workout.totalSets} sets',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Started ${_formatDateTime(workout.startedAt)}'),
                if (workout.completedAt != null) ...[
                  const SizedBox(height: 4),
                  Text('Completed ${_formatDateTime(workout.completedAt!)}'),
                  const SizedBox(height: 4),
                  Text(
                    'Duration ${_formatDuration(workout.startedAt, workout.completedAt!)}',
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Exercises',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        for (final exercise in workout.exercises)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HistoryExerciseCard(exercise: exercise),
          ),
      ],
    );
  }
}

class _HistoryExerciseCard extends StatelessWidget {
  const _HistoryExerciseCard({required this.exercise});

  final WorkoutExerciseData exercise;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.exerciseName,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(
                  label: Text(
                    exercise.isSkipped
                        ? 'Skipped'
                        : exercise.isCompleted
                        ? 'Completed'
                        : exercise.status,
                  ),
                ),
              ],
            ),

            if (exercise.isSkipped) ...[
              const SizedBox(height: 8),
              const Text('This exercise was skipped.'),
            ] else ...[
              const SizedBox(height: 12),

              for (final workoutSet in exercise.sets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HistorySetRow(workoutSet: workoutSet),
                ),
            ],
          ],
        ),
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

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            'Set ${workoutSet.setNumber}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            workoutSet.isCompleted ? details.join(' • ') : 'Not completed',
          ),
        ),
        Icon(
          workoutSet.isCompleted
              ? Icons.check_circle_outline
              : Icons.radio_button_unchecked,
          size: 20,
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();

  final day = local.day.toString().padLeft(2, '0');

  final month = local.month.toString().padLeft(2, '0');

  final hour = local.hour.toString().padLeft(2, '0');

  final minute = local.minute.toString().padLeft(2, '0');

  return '$day/$month/${local.year} '
      '$hour:$minute';
}

String _formatDuration(DateTime startedAt, DateTime completedAt) {
  final duration = completedAt.difference(startedAt);

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
