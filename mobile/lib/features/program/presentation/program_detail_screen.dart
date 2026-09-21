import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
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
        builder: (context) {
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
      appBar: AppBar(title: const Text('Training Program')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _ProgramHeader(program: program),
            const SizedBox(height: 24),
            Text(
              'Weekly Schedule',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final day in days)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProgramDayCard(
                  day: day,
                  currentWorkout: currentWorkout,
                  isStarting: _startingDayId == day.id,
                  startBlocked: _startingDayId != null,
                  onStart: () {
                    _startWorkout(day);
                  },
                  onResume: _openWorkout,
                ),
              ),
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    program.name,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(label: Text('v${program.versionNumber}')),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.flag_outlined, size: 18),
                  label: Text(_goalLabel(program.goal)),
                ),
                Chip(
                  avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text('${program.days.length} days'),
                ),
                Chip(
                  avatar: const Icon(Icons.fitness_center, size: 18),
                  label: Text('${program.totalExercises} exercises'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Generated with FORGE '
              '${program.generatorVersion}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
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

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: isCurrentWorkout || day.dayOrder == 1,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                day.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isCurrentWorkout)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Chip(
                  avatar: Icon(Icons.play_arrow, size: 18),
                  label: Text('In Progress'),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${weekdayLabel(day.dayOfWeek)}'
            ' \u2022 '
            '${day.estimatedDurationMinutes} min'
            ' \u2022 '
            '${day.exercises.length} exercises',
          ),
        ),
        children: [
          const Divider(),
          for (final exercise in day.exercises)
            _ExerciseRow(exercise: exercise),
          const SizedBox(height: 12),
          if (isCurrentWorkout)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Resume Workout'),
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
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    isStarting
                        ? 'Starting...'
                        : anotherWorkoutIsActive
                        ? 'Another Workout Is Active'
                        : 'Start Workout',
                  ),
                ),
              ),
            ),
        ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 18, child: Text('${exercise.exerciseOrder}')),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exerciseName,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercise.sets} sets '
                  '\u00d7 '
                  '$reps reps',
                ),
                const SizedBox(height: 2),
                Text(
                  '${exercise.restSeconds} '
                  'sec rest',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
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
