import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../program/presentation/program_controller.dart';
import '../../program/presentation/program_detail_screen.dart';
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Could not load your training data.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await Future.wait([
                      ref.read(programControllerProvider.notifier).refresh(),
                      ref.read(workoutControllerProvider.notifier).refresh(),
                    ]);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
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
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Training',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('Your current workout and training program.'),
            const SizedBox(height: 24),

            if (workout != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Workout in progress',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        workout.dayName,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${workout.completedSets}'
                        '/${workout.totalSets} '
                        'sets completed',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) {
                                  return const WorkoutSessionScreen();
                                },
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Resume Workout'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (program != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Program',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        program.name,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${program.days.length} '
                        'training days • '
                        '${program.totalExercises} '
                        'exercises',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) {
                                  return ProgramDetailScreen(program: program);
                                },
                              ),
                            );
                          },
                          icon: const Icon(Icons.calendar_month),
                          label: const Text('View Training Program'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No active training program.'),
                ),
              ),
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
    return AppBar(title: const Text('Train'));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
