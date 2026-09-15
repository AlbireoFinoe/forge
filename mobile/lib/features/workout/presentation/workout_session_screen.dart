import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../data/workout_models.dart';
import '../data/workout_repository.dart';
import 'workout_controller.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key});

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  bool _isFinishing = false;

  Future<void> _logSet(
    WorkoutExerciseData exercise,
    WorkoutSetData workoutSet,
  ) async {
    final result = await showDialog<_SetLogResult>(
      context: context,
      builder: (context) {
        return _SetLogDialog(exercise: exercise, workoutSet: workoutSet);
      },
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      await ref
          .read(workoutControllerProvider.notifier)
          .logSet(
            workoutSetId: workoutSet.id,
            actualReps: result.actualReps,
            weightKg: result.weightKg,
            rpe: result.rpe,
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
            'Your completed sets will be saved to your workout history.',
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

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(Icons.check_circle_outline, size: 48),
            title: const Text('Workout Complete'),
            content: Text(
              '${completed.dayName} has been saved to your workout history.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on WorkoutException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
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

    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
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
            isFinishing: _isFinishing,
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
    required this.isFinishing,
    required this.onLogSet,
    required this.onSkipExercise,
    required this.onFinish,
  });

  final WorkoutSessionData workout;
  final bool isFinishing;

  final void Function(WorkoutExerciseData exercise, WorkoutSetData workoutSet)
  onLogSet;

  final void Function(WorkoutExerciseData exercise) onSkipExercise;

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final completedExercises = workout.exercises
        .where((exercise) => exercise.isCompleted || exercise.isSkipped)
        .length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            workout.dayName,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${weekdayLabel(workout.dayOfWeek)} • '
            'Program v${workout.programVersionNumber}',
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: _ProgressStat(
                      label: 'Exercises',
                      value: '$completedExercises/${workout.exercises.length}',
                    ),
                  ),
                  Expanded(
                    child: _ProgressStat(
                      label: 'Sets',
                      value: '${workout.completedSets}/${workout.totalSets}',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          for (final exercise in workout.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _WorkoutExerciseCard(
                exercise: exercise,
                onLogSet: (set) {
                  onLogSet(exercise, set);
                },
                onSkip: () {
                  onSkipExercise(exercise);
                },
              ),
            ),

          const SizedBox(height: 8),

          if (workout.pendingExercises > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Complete or skip '
                '${workout.pendingExercises} remaining '
                '${workout.pendingExercises == 1 ? 'exercise' : 'exercises'} '
                'before finishing.',
                textAlign: TextAlign.center,
              ),
            ),

          FilledButton.icon(
            onPressed: workout.pendingExercises == 0 && !isFinishing
                ? onFinish
                : null,
            icon: const Icon(Icons.flag_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: isFinishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Finish Workout'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}

class _WorkoutExerciseCard extends StatelessWidget {
  const _WorkoutExerciseCard({
    required this.exercise,
    required this.onLogSet,
    required this.onSkip,
  });

  final WorkoutExerciseData exercise;
  final ValueChanged<WorkoutSetData> onLogSet;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final reps = exercise.targetMinReps == exercise.targetMaxReps
        ? '${exercise.targetMinReps}'
        : '${exercise.targetMinReps}–'
              '${exercise.targetMaxReps}';

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
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _ExerciseStatusChip(exercise: exercise),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              '${exercise.targetSets} sets × '
              '$reps reps • '
              '${exercise.targetRestSeconds} sec rest',
            ),

            const SizedBox(height: 20),

            for (final workoutSet in exercise.sets)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WorkoutSetTile(
                  workoutSet: workoutSet,
                  enabled: !exercise.isSkipped,
                  onTap: () {
                    onLogSet(workoutSet);
                  },
                ),
              ),

            if (exercise.isPending) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onSkip,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Skip Exercise'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseStatusChip extends StatelessWidget {
  const _ExerciseStatusChip({required this.exercise});

  final WorkoutExerciseData exercise;

  @override
  Widget build(BuildContext context) {
    if (exercise.isCompleted) {
      return const Chip(
        avatar: Icon(Icons.check, size: 18),
        label: Text('Completed'),
      );
    }

    if (exercise.isSkipped) {
      return const Chip(
        avatar: Icon(Icons.skip_next, size: 18),
        label: Text('Skipped'),
      );
    }

    return Chip(
      label: Text(
        '${exercise.completedSetCount}'
        '/${exercise.sets.length} sets',
      ),
    );
  }
}

class _WorkoutSetTile extends StatelessWidget {
  const _WorkoutSetTile({
    required this.workoutSet,
    required this.enabled,
    required this.onTap,
  });

  final WorkoutSetData workoutSet;
  final bool enabled;
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

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text('${workoutSet.setNumber}')),
      title: Text('Set ${workoutSet.setNumber}'),
      subtitle: Text(
        workoutSet.isCompleted ? details.join(' • ') : 'Not logged yet',
      ),
      trailing: Icon(
        workoutSet.isCompleted ? Icons.check_circle : Icons.add_circle_outline,
      ),
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
  }
}

class _SetLogDialog extends StatefulWidget {
  const _SetLogDialog({required this.exercise, required this.workoutSet});

  final WorkoutExerciseData exercise;
  final WorkoutSetData workoutSet;

  @override
  State<_SetLogDialog> createState() => _SetLogDialogState();
}

class _SetLogDialogState extends State<_SetLogDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _weightController;
  late final TextEditingController _repsController;
  late final TextEditingController _rpeController;

  @override
  void initState() {
    super.initState();

    _weightController = TextEditingController(
      text: widget.workoutSet.weightKg == null
          ? ''
          : _formatNumber(widget.workoutSet.weightKg!),
    );

    _repsController = TextEditingController(
      text: widget.workoutSet.actualReps?.toString() ?? '',
    );

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
    return AlertDialog(
      title: Text(
        '${widget.exercise.exerciseName} '
        '— Set ${widget.workoutSet.setNumber}',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  suffixText: 'kg',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return null;
                  }

                  final weight = double.tryParse(text);

                  if (weight == null || weight < 0) {
                    return 'Enter a valid weight.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _repsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Reps'),
                validator: (value) {
                  final reps = int.tryParse(value?.trim() ?? '');

                  if (reps == null || reps < 0) {
                    return 'Enter valid reps.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _rpeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'RPE',
                  hintText: 'Optional',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return null;
                  }

                  final rpe = double.tryParse(text);

                  if (rpe == null || rpe < 1 || rpe > 10) {
                    return 'RPE must be between 1 and 10.';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.workoutSet.isCompleted ? 'Update Set' : 'Save Set',
          ),
        ),
      ],
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
