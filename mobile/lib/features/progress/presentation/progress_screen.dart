import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../../program/presentation/program_controller.dart';
import '../../workout/presentation/workout_controller.dart';
import '../../workout/presentation/workout_history_screen.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync =
        ref.watch(programControllerProvider);

    final workoutAsync =
        ref.watch(workoutControllerProvider);

    if (programAsync.isLoading ||
        workoutAsync.isLoading) {
      return const Scaffold(
        appBar: _ProgressAppBar(),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final program =
        programAsync.value?.currentProgram;

    final workoutState =
        workoutAsync.value;

    if (program == null ||
        workoutState == null) {
      return const Scaffold(
        appBar: _ProgressAppBar(),
        body: Center(
          child: Text(
            'Progress data is not available yet.',
          ),
        ),
      );
    }

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final weekStart = today.subtract(
      Duration(
        days: now.weekday - 1,
      ),
    );

    final weekEnd =
        weekStart.add(
      const Duration(days: 7),
    );

    final completedDays = <int>{};

    for (final workout
        in workoutState.history) {
      final completedAt =
          workout.completedAt;

      if (workout.status != 'completed' ||
          completedAt == null ||
          workout.programVersionNumber !=
              program.versionNumber) {
        continue;
      }

      final local = completedAt.toLocal();

      if (!local.isBefore(weekStart) &&
          local.isBefore(weekEnd)) {
        completedDays.add(
          workout.dayOfWeek,
        );
      }
    }

    final days = [...program.days]
      ..sort(
        (a, b) =>
            a.dayOrder.compareTo(
          b.dayOrder,
        ),
      );

    final scheduledDays = days
        .map(
          (day) => day.dayOfWeek,
        )
        .toSet();

    final completedCount =
        completedDays
            .where(
              scheduledDays.contains,
            )
            .length;

    final totalDays =
        scheduledDays.length;

    final progress = totalDays == 0
        ? 0.0
        : completedCount / totalDays;

    return Scaffold(
      appBar: const _ProgressAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref
                .read(
                  programControllerProvider.notifier,
                )
                .refresh(),
            ref
                .read(
                  workoutControllerProvider.notifier,
                )
                .refresh(),
          ]);
        },
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'This Week',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '$completedCount / $totalDays '
              'workouts completed',
            ),
            const SizedBox(height: 16),

            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius:
                  BorderRadius.circular(99),
            ),

            const SizedBox(height: 24),

            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0;
                      i < days.length;
                      i++) ...[
                    ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          completedDays.contains(
                            days[i].dayOfWeek,
                          )
                              ? Icons.check
                              : Icons
                                  .radio_button_unchecked,
                        ),
                      ),
                      title: Text(
                        weekdayLabel(
                          days[i].dayOfWeek,
                        ),
                      ),
                      subtitle: Text(
                        days[i].name,
                      ),
                      trailing: Text(
                        completedDays.contains(
                          days[i].dayOfWeek,
                        )
                            ? 'Completed'
                            : 'Scheduled',
                      ),
                    ),
                    if (i !=
                        days.length - 1)
                      const Divider(
                        height: 1,
                      ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) {
                        return const WorkoutHistoryScreen();
                      },
                    ),
                  );
                },
                icon: const Icon(
                  Icons.history,
                ),
                label: const Text(
                  'View Workout History',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _ProgressAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Progress'),
    );
  }

  @override
  Size get preferredSize =>
      const Size.fromHeight(
        kToolbarHeight,
      );
}