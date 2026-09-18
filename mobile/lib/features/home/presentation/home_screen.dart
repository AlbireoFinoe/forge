import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../../auth/data/auth_user.dart';
import '../../program/data/program_models.dart';
import '../../program/data/program_repository.dart';
import '../../program/presentation/program_controller.dart';
import '../../program/presentation/program_detail_screen.dart';
import '../../workout/data/workout_models.dart';
import '../../workout/data/workout_repository.dart';
import '../../workout/presentation/workout_controller.dart';
import '../../workout/presentation/workout_session_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({required this.user, super.key});

  final AuthUser user;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isGenerating = false;
  bool _isStartingWorkout = false;

  Future<void> _generateProgram({required bool replacingExisting}) async {
    if (_isGenerating) {
      return;
    }

    if (replacingExisting) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Generate a new program?'),
            content: const Text(
              'Your current program will be archived and FORGE will create a new version using your latest training setup.',
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
                child: const Text('Generate'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final result = await ref
          .read(programControllerProvider.notifier)
          .generateProgram();

      if (!mounted) {
        return;
      }

      final warningText = result.warnings.isEmpty
          ? ''
          : ' ${result.warnings.length} warning(s) were reported.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Program v${result.versionNumber} generated successfully.$warningText',
          ),
        ),
      );
    } on ProgramException catch (error) {
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
        const SnackBar(
          content: Text('Could not generate your training program.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

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
    if (_isStartingWorkout) {
      return;
    }

    setState(() {
      _isStartingWorkout = true;
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
    } finally {
      if (mounted) {
        setState(() {
          _isStartingWorkout = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = ref.watch(programControllerProvider);
    final workout = ref.watch(workoutControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FORGE'),
        actions: [
          IconButton(
            onPressed: () async {
              await Future.wait([
                ref.read(programControllerProvider.notifier).refresh(),
                ref.read(workoutControllerProvider.notifier).refresh(),
              ]);
            },
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: program.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return _ProgramLoadError(
            error: error,
            onRetry: () {
              ref.read(programControllerProvider.notifier).refresh();
            },
          );
        },
        data: (data) {
          return workout.when(
            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
            error: (error, stackTrace) {
              return _ProgramLoadError(
                error: error,
                onRetry: () {
                  ref.read(workoutControllerProvider.notifier).refresh();
                },
              );
            },
            data: (workoutState) {
              return _HomeContent(
                user: widget.user,
                state: data,
                workoutState: workoutState,
                isGenerating: _isGenerating,
                isStartingWorkout: _isStartingWorkout,
                onGenerate: () {
                  _generateProgram(replacingExisting: false);
                },
                onRegenerate: () {
                  _generateProgram(replacingExisting: true);
                },
                onStartWorkout: _startWorkout,
                onResumeWorkout: _openWorkout,
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.user,
    required this.state,
    required this.workoutState,
    required this.isGenerating,
    required this.onGenerate,
    required this.onRegenerate,
    required this.isStartingWorkout,
    required this.onStartWorkout,
    required this.onResumeWorkout,
  });

  final AuthUser user;
  final ProgramState state;
  final WorkoutState workoutState;
  final bool isGenerating;
  final bool isStartingWorkout;
  final VoidCallback onGenerate;
  final VoidCallback onRegenerate;
  final ValueChanged<ProgramDayData> onStartWorkout;
  final VoidCallback onResumeWorkout;

  @override
  Widget build(BuildContext context) {
    final program = state.currentProgram;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(user.email, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 32),

                if (program == null)
                  _NoProgramCard(
                    isGenerating: isGenerating,
                    onGenerate: onGenerate,
                  )
                else ...[
                  if (program.isOutdated) ...[
                    _ProgramOutdatedCard(
                      isGenerating: isGenerating,
                      onRegenerate: onRegenerate,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _TodayTrainingCard(
                    program: program,
                    currentWorkout: workoutState.currentWorkout,
                    completedToday: workoutState.completedToday,
                    isStartingWorkout: isStartingWorkout,
                    onStartWorkout: onStartWorkout,
                    onResumeWorkout: onResumeWorkout,
                  ),
                  const SizedBox(height: 16),
                  _WeeklyProgressCard(
                    program: program,
                    workoutState: workoutState,
                  ),
                  const SizedBox(height: 16),
                  _ActiveProgramCard(
                    program: program,
                    onViewProgram: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) {
                            return ProgramDetailScreen(program: program);
                          },
                        ),
                      );
                    },
                  ),

                  if (state.lastGeneration?.warnings.isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    _GenerationWarningCard(generation: state.lastGeneration!),
                  ],

                  if (!program.isOutdated) ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: isGenerating ? null : onRegenerate,
                      icon: const Icon(Icons.auto_awesome),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: isGenerating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Generate New Program'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgramOutdatedCard extends StatelessWidget {
  const _ProgramOutdatedCard({
    required this.isGenerating,
    required this.onRegenerate,
  });

  final bool isGenerating;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.update, color: colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Training setup changed',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your active program was created '
                        'from an older training setup. '
                        'Regenerate it to apply your latest '
                        'goals, schedule, experience, muscle '
                        'priorities, equipment, and sports.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isGenerating ? null : onRegenerate,
                icon: const Icon(Icons.auto_awesome),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Regenerate Program'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoProgramCard extends StatelessWidget {
  const _NoProgramCard({required this.isGenerating, required this.onGenerate});

  final bool isGenerating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.fitness_center, size: 48),
            const SizedBox(height: 16),
            Text(
              'Your training setup is ready',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'FORGE can now build a training program using your goals, experience, schedule, muscle priorities, equipment, and sports activities.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: isGenerating ? null : onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Generate My Program'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayTrainingCard extends StatelessWidget {
  const _TodayTrainingCard({
    required this.program,
    required this.currentWorkout,
    required this.completedToday,
    required this.isStartingWorkout,
    required this.onStartWorkout,
    required this.onResumeWorkout,
  });

  final ProgramDetailData program;
  final WorkoutSessionData? currentWorkout;
  final WorkoutSummaryData? completedToday;
  final bool isStartingWorkout;
  final ValueChanged<ProgramDayData> onStartWorkout;
  final VoidCallback onResumeWorkout;

  ProgramDayData? _todaySession() {
    final today = DateTime.now().weekday;

    for (final day in program.days) {
      if (day.dayOfWeek == today) {
        return day;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = _todaySession();
    final inProgress = currentWorkout;
    final completed = completedToday;
    final completedScheduledSession =
        session != null &&
        completed != null &&
        completed.programVersionNumber == program.versionNumber &&
        completed.dayOfWeek == session.dayOfWeek;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's Training",
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),

            if (session == null) ...[
              Row(
                children: [
                  const Icon(Icons.self_improvement, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recovery Day',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text('No programmed gym session today.'),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                session.name,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${weekdayLabel(session.dayOfWeek)} • '
                '${session.estimatedDurationMinutes} min • '
                '${session.exercises.length} exercises',
              ),
              const SizedBox(height: 12),
              Text(
                'Your workout is ready. The interactive workout session will be connected in the next training step.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (inProgress != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onResumeWorkout,
                  icon: const Icon(Icons.play_arrow),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Resume ${inProgress.dayName}'),
                  ),
                ),
              ),
            ] else if (completedScheduledSession) ...[
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.check_circle),
                  SizedBox(width: 8),
                  Text(
                    'Workout completed today',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ] else if (session != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isStartingWorkout
                      ? null
                      : () {
                          onStartWorkout(session);
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: isStartingWorkout
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Start Workout'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({
    required this.program,
    required this.workoutState,
  });

  final ProgramDetailData program;
  final WorkoutState workoutState;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final scheduledDays = program.days.map((day) => day.dayOfWeek).toSet();
    final completedDays = <int>{};

    for (final workout in workoutState.history) {
      final completedAt = workout.completedAt;

      if (workout.status != 'completed' ||
          completedAt == null ||
          workout.programVersionNumber != program.versionNumber) {
        continue;
      }

      final local = completedAt.toLocal();

      if (!local.isBefore(weekStart) &&
          local.isBefore(weekEnd) &&
          scheduledDays.contains(workout.dayOfWeek)) {
        completedDays.add(workout.dayOfWeek);
      }
    }

    final completedCount = completedDays.length;
    final totalDays = scheduledDays.length;
    final progress = totalDays == 0 ? 0.0 : completedCount / totalDays;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Weekly Progress',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '$completedCount / $totalDays',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 12),
            Text(
              completedCount == totalDays && totalDays > 0
                  ? 'Weekly training complete.'
                  : '$completedCount of $totalDays scheduled workouts completed.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveProgramCard extends StatelessWidget {
  const _ActiveProgramCard({
    required this.program,
    required this.onViewProgram,
  });

  final ProgramDetailData program;
  final VoidCallback onViewProgram;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Active Program',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(label: Text('v${program.versionNumber}')),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              program.name,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${_goalLabel(program.goal)} • '
              '${program.days.length} training days',
            ),
            const SizedBox(height: 4),
            Text(
              '${program.totalExercises} exercise assignments • '
              'Generator ${program.generatorVersion}',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onViewProgram,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('View Program'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerationWarningCard extends StatelessWidget {
  const _GenerationWarningCard({required this.generation});

  final ProgramGenerateData generation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Program generated successfully with '
                '${generation.warnings.length} optimization warning(s). '
                'These are not generation failures.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramLoadError extends StatelessWidget {
  const _ProgramLoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 16),
            const Text('Could not load your training program.'),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
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
