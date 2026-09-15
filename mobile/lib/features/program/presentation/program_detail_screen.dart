import 'package:flutter/material.dart';

import '../../../core/constants/weekdays.dart';
import '../data/program_models.dart';

class ProgramDetailScreen extends StatelessWidget {
  const ProgramDetailScreen({required this.program, super.key});

  final ProgramDetailData program;

  @override
  Widget build(BuildContext context) {
    final days = [...program.days]
      ..sort((left, right) => left.dayOrder.compareTo(right.dayOrder));

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
                child: _ProgramDayCard(day: day),
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
              'Generated with FORGE ${program.generatorVersion}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramDayCard extends StatelessWidget {
  const _ProgramDayCard({required this.day});

  final ProgramDayData day;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: day.dayOrder == 1,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          day.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${weekdayLabel(day.dayOfWeek)} • '
            '${day.estimatedDurationMinutes} min • '
            '${day.exercises.length} exercises',
          ),
        ),
        children: [
          const Divider(),

          for (final exercise in day.exercises)
            _ExerciseRow(exercise: exercise),
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
        : '${exercise.minReps}–${exercise.maxReps}';

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
                Text('${exercise.sets} sets × $reps reps'),
                const SizedBox(height: 2),
                Text(
                  '${exercise.restSeconds} sec rest',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
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
