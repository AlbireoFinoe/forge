import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../../../core/theme/forge_theme.dart';
import '../data/workout_models.dart';
import 'workout_controller.dart';
import 'workout_history_detail_screen.dart';

class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('WORKOUT HISTORY')),
      body: workout.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return _HistoryErrorState(
            onRetry: () {
              ref.read(workoutControllerProvider.notifier).refresh();
            },
          );
        },
        data: (state) {
          if (state.history.isEmpty) {
            return const _EmptyHistory();
          }

          return RefreshIndicator(
            onRefresh: () {
              return ref.read(workoutControllerProvider.notifier).refresh();
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
                  'WORKOUT HISTORY',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Your completed training sessions.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: ForgeColors.textSecondary),
                ),

                const SizedBox(height: ForgeSpacing.xl),

                _HistoryCountHeader(count: state.history.length),

                const SizedBox(height: ForgeSpacing.md),

                for (var index = 0; index < state.history.length; index++) ...[
                  _WorkoutHistoryCard(
                    workout: state.history[index],
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) {
                            return WorkoutHistoryDetailScreen(
                              workoutId: state.history[index].id,
                            );
                          },
                        ),
                      );
                    },
                  ),

                  if (index < state.history.length - 1)
                    const SizedBox(height: ForgeSpacing.md),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCountHeader extends StatelessWidget {
  const _HistoryCountHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'SESSIONS',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
        const Spacer(),
        Text(
          '$count TOTAL',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ForgeColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WorkoutHistoryCard extends StatelessWidget {
  const _WorkoutHistoryCard({required this.workout, required this.onTap});

  final WorkoutSummaryData workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timestamp = workout.completedAt ?? workout.startedAt;

    final isCompleted = workout.status == 'completed';

    return Material(
      color: ForgeColors.surface,
      borderRadius: BorderRadius.circular(ForgeRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(ForgeSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ForgeRadius.lg),
            border: Border.all(
              color: isCompleted
                  ? ForgeColors.success.withValues(alpha: 0.15)
                  : ForgeColors.outline,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? ForgeColors.success.withValues(alpha: 0.10)
                      : ForgeColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(ForgeRadius.md),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_rounded
                      : Icons.fitness_center_rounded,
                  color: isCompleted
                      ? ForgeColors.success
                      : ForgeColors.textSecondary,
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
                            workout.dayName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        _WorkoutStatusBadge(completed: isCompleted),
                      ],
                    ),

                    const SizedBox(height: 7),

                    Text(
                      '${weekdayLabel(timestamp.toLocal().weekday)}'
                      ' \u2022 '
                      'Program v${workout.programVersionNumber}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ForgeColors.textSecondary),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _formatHistoryDate(timestamp),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: ForgeColors.textMuted),
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

class _WorkoutStatusBadge extends StatelessWidget {
  const _WorkoutStatusBadge({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: completed
            ? ForgeColors.success.withValues(alpha: 0.10)
            : ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        completed ? 'COMPLETED' : 'SESSION',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: completed ? ForgeColors.success : ForgeColors.textMuted,
          fontWeight: FontWeight.w800,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ForgeSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_rounded,
              size: 52,
              color: ForgeColors.textMuted,
            ),
            const SizedBox(height: ForgeSpacing.lg),
            Text(
              'No workout history yet',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Completed workouts will '
              'appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: ForgeColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({required this.onRetry});

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
              'Could not load history',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection '
              'and try again.',
              textAlign: TextAlign.center,
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

String _formatHistoryDate(DateTime value) {
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
