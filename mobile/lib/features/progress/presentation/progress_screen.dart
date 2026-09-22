import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/weekdays.dart';
import '../../../core/theme/forge_theme.dart';
import '../../program/presentation/program_controller.dart';
import '../../workout/data/workout_models.dart';
import '../../workout/presentation/workout_controller.dart';
import '../../workout/presentation/workout_history_screen.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(programControllerProvider);

    final workoutAsync = ref.watch(workoutControllerProvider);

    if (programAsync.isLoading || workoutAsync.isLoading) {
      return const Scaffold(
        appBar: _ProgressAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (programAsync.hasError || workoutAsync.hasError) {
      return Scaffold(
        appBar: const _ProgressAppBar(),
        body: _ProgressErrorState(
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

    final workoutState = workoutAsync.value;

    if (program == null || workoutState == null) {
      return const Scaffold(
        appBar: _ProgressAppBar(),
        body: _ProgressEmptyState(),
      );
    }

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final weekStart = today.subtract(Duration(days: now.weekday - 1));

    final weekEnd = weekStart.add(const Duration(days: 7));

    final completedThisWeek =
        workoutState.history.where((workout) {
          final completedAt = workout.completedAt;

          if (workout.status != 'completed' ||
              completedAt == null ||
              workout.programVersionNumber != program.versionNumber) {
            return false;
          }

          final local = completedAt.toLocal();

          return !local.isBefore(weekStart) && local.isBefore(weekEnd);
        }).toList()..sort((left, right) {
          final leftTime = left.completedAt ?? left.startedAt;

          final rightTime = right.completedAt ?? right.startedAt;

          return rightTime.compareTo(leftTime);
        });

    final completedDays = completedThisWeek
        .map((workout) => workout.dayOfWeek)
        .toSet();

    final scheduledDays = program.days.map((day) => day.dayOfWeek).toSet();

    final completedCount = completedDays.where(scheduledDays.contains).length;

    final totalDays = scheduledDays.length;

    final progress = totalDays == 0 ? 0.0 : completedCount / totalDays;

    final remaining = totalDays - completedCount;

    return Scaffold(
      appBar: const _ProgressAppBar(),
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
              'PROGRESS',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.4),
            ),

            const SizedBox(height: 6),

            Text(
              'Your training consistency.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: ForgeColors.textSecondary),
            ),

            const SizedBox(height: ForgeSpacing.xl),

            _WeeklyProgressCard(
              completedCount: completedCount,
              totalDays: totalDays,
              progress: progress,
              remaining: remaining,
            ),

            const SizedBox(height: ForgeSpacing.xxl),

            _SectionHeader(
              title: 'THIS WEEK',
              trailing: '${completedThisWeek.length} SESSIONS',
            ),

            const SizedBox(height: ForgeSpacing.md),

            _RecentActivity(workouts: completedThisWeek),

            const SizedBox(height: ForgeSpacing.xxl),

            const _SectionHeader(title: 'TRAINING HISTORY', trailing: 'LOG'),

            const SizedBox(height: ForgeSpacing.md),

            _HistoryCard(
              onOpen: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) {
                      return const WorkoutHistoryScreen();
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ProgressAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(toolbarHeight: 0);
  }

  @override
  Size get preferredSize => Size.zero;
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({
    required this.completedCount,
    required this.totalDays,
    required this.progress,
    required this.remaining,
  });

  final int completedCount;
  final int totalDays;
  final double progress;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).round();

    final isComplete = totalDays > 0 && completedCount >= totalDays;

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.xl),
      decoration: BoxDecoration(
        color: ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(
          color: isComplete
              ? ForgeColors.primary.withValues(alpha: 0.24)
              : ForgeColors.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percentage',
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w900, height: 0.9),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 3, bottom: 3),
                child: Text(
                  '%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: ForgeColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            'WEEKLY COMPLETION',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ForgeColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: ForgeSpacing.xl),

          Row(
            children: [
              Text(
                '$completedCount of '
                '$totalDays workouts completed',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.md),

          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: ForgeColors.surfaceSoft,
              color: ForgeColors.primary,
            ),
          ),

          const SizedBox(height: ForgeSpacing.lg),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ForgeSpacing.md),
            decoration: BoxDecoration(
              color: isComplete
                  ? ForgeColors.primary.withValues(alpha: 0.08)
                  : ForgeColors.surface,
              borderRadius: BorderRadius.circular(ForgeRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  isComplete
                      ? Icons.check_circle_rounded
                      : Icons.fitness_center_rounded,
                  size: 20,
                  color: isComplete
                      ? ForgeColors.primary
                      : ForgeColors.textSecondary,
                ),

                const SizedBox(width: ForgeSpacing.md),

                Expanded(
                  child: Text(
                    isComplete
                        ? 'Weekly training complete.'
                        : remaining == 1
                        ? '1 workout remaining this week.'
                        : '$remaining workouts remaining this week.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isComplete
                          ? ForgeColors.primary
                          : ForgeColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.workouts});

  final List<WorkoutSummaryData> workouts;

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ForgeSpacing.xl),
        decoration: BoxDecoration(
          color: ForgeColors.surface,
          borderRadius: BorderRadius.circular(ForgeRadius.lg),
          border: Border.all(color: ForgeColors.outline),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.fitness_center_outlined,
              color: ForgeColors.textMuted,
              size: 30,
            ),

            const SizedBox(height: ForgeSpacing.md),

            Text(
              'No completed workouts yet',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 4),

            Text(
              'Completed sessions from this '
              'week will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: ForgeColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final visible = workouts.take(4).toList();

    return Column(
      children: [
        for (var index = 0; index < visible.length; index++) ...[
          _RecentWorkoutRow(workout: visible[index]),

          if (index < visible.length - 1)
            const SizedBox(height: ForgeSpacing.sm),
        ],
      ],
    );
  }
}

class _RecentWorkoutRow extends StatelessWidget {
  const _RecentWorkoutRow({required this.workout});

  final WorkoutSummaryData workout;

  @override
  Widget build(BuildContext context) {
    final timestamp = workout.completedAt ?? workout.startedAt;

    final local = timestamp.toLocal();

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        border: Border.all(color: ForgeColors.success.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ForgeColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(ForgeRadius.sm),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: ForgeColors.success,
              size: 22,
            ),
          ),

          const SizedBox(width: ForgeSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.dayName,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),

                const SizedBox(height: 4),

                Text(
                  '${weekdayLabel(local.weekday)}'
                  ' \u2022 '
                  '${_formatActivityDate(local)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: ForgeColors.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Text(
            'DONE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ForgeColors.success,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.onOpen});

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
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ForgeColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(ForgeRadius.sm),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: ForgeColors.primary,
            ),
          ),

          const SizedBox(height: ForgeSpacing.lg),

          Text(
            'Workout history',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 6),

          Text(
            'Review completed workouts '
            'and your logged set performance.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: ForgeColors.textSecondary),
          ),

          const SizedBox(height: ForgeSpacing.lg),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('VIEW WORKOUT HISTORY'),
              ),
            ),
          ),
        ],
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

class _ProgressEmptyState extends StatelessWidget {
  const _ProgressEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ForgeSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insights_outlined,
              size: 48,
              color: ForgeColors.textMuted,
            ),
            const SizedBox(height: ForgeSpacing.lg),
            Text(
              'No progress data yet',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Complete workouts from an '
              'active program to start '
              'tracking weekly progress.',
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

class _ProgressErrorState extends StatelessWidget {
  const _ProgressErrorState({required this.onRetry});

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
              'Could not load progress',
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

String _formatActivityDate(DateTime value) {
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

  return '${months[value.month - 1]} '
      '${value.day}';
}
