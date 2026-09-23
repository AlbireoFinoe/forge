import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';
import '../data/exercise_models.dart';
import 'exercise_detail_provider.dart';
import 'muscle_visual_assets.dart';

Future<void> showExerciseDetailSheet(
  BuildContext context, {
  required String exerciseId,
  required String exerciseName,
  int? sets,
  int? minReps,
  int? maxReps,
  int? restSeconds,
  bool showSecondaryMuscles = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: ForgeColors.surfaceRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ForgeRadius.xl)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) {
      return FractionallySizedBox(
        heightFactor: 0.90,
        child: ExerciseDetailSheet(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          sets: sets,
          minReps: minReps,
          maxReps: maxReps,
          restSeconds: restSeconds,
          showSecondaryMuscles: showSecondaryMuscles,
        ),
      );
    },
  );
}

class ExerciseDetailSheet extends ConsumerWidget {
  const ExerciseDetailSheet({
    required this.exerciseId,
    required this.exerciseName,
    this.sets,
    this.minReps,
    this.maxReps,
    this.restSeconds,
    this.showSecondaryMuscles = true,
    super.key,
  });

  final String exerciseId;
  final String exerciseName;

  final int? sets;
  final int? minReps;
  final int? maxReps;
  final int? restSeconds;

  final bool showSecondaryMuscles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(exerciseDetailProvider(exerciseId));

    return Column(
      children: [
        const SizedBox(height: ForgeSpacing.sm),

        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: ForgeColors.outlineStrong,
            borderRadius: BorderRadius.circular(99),
          ),
        ),

        const SizedBox(height: ForgeSpacing.md),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ForgeSpacing.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXERCISE DETAIL',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ForgeColors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      exerciseName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Close',
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),

        const SizedBox(height: ForgeSpacing.md),

        const Divider(height: 1, color: ForgeColors.outline),

        Expanded(
          child: detailState.when(
            loading: () {
              return const _ExerciseDetailLoading();
            },
            error: (error, stackTrace) {
              return _ExerciseDetailError(
                onRetry: () {
                  ref.invalidate(exerciseDetailProvider(exerciseId));
                },
              );
            },
            data: (detail) {
              return _ExerciseDetailContent(
                detail: detail,
                sets: sets,
                minReps: minReps,
                maxReps: maxReps,
                restSeconds: restSeconds,
                showSecondaryMuscles: showSecondaryMuscles,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExerciseDetailLoading extends StatelessWidget {
  const _ExerciseDetailLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ExerciseDetailError extends StatelessWidget {
  const _ExerciseDetailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ForgeSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ForgeColors.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(ForgeRadius.md),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: ForgeColors.error,
              ),
            ),

            const SizedBox(height: ForgeSpacing.lg),

            Text(
              'Could not load exercise details',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: ForgeSpacing.sm),

            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: ForgeColors.textSecondary),
            ),

            const SizedBox(height: ForgeSpacing.lg),

            OutlinedButton.icon(
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

class _ExerciseDetailContent extends StatelessWidget {
  const _ExerciseDetailContent({
    required this.detail,
    required this.sets,
    required this.minReps,
    required this.maxReps,
    required this.restSeconds,
    required this.showSecondaryMuscles,
  });

  final ExerciseDetailData detail;

  final int? sets;
  final int? minReps;
  final int? maxReps;
  final int? restSeconds;

  final bool showSecondaryMuscles;

  @override
  Widget build(BuildContext context) {
    final effectiveMinReps = minReps ?? detail.minReps;

    final effectiveMaxReps = maxReps ?? detail.maxReps;

    final effectiveRestSeconds = restSeconds ?? detail.restSeconds;

    final reps = effectiveMinReps == effectiveMaxReps
        ? '$effectiveMinReps'
        : '$effectiveMinReps'
              '\u2013'
              '$effectiveMaxReps';

    final prescribedSets = sets;

    final hasPrescription = prescribedSets != null;

    final secondary = [...detail.secondaryMuscles]
      ..sort(
        (left, right) =>
            right.contributionWeight.compareTo(left.contributionWeight),
      );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        ForgeSpacing.xl,
        ForgeSpacing.xl,
        ForgeSpacing.xl,
        ForgeSpacing.xxl + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: ForgeSpacing.sm,
            runSpacing: ForgeSpacing.sm,
            children: [
              _InfoChip(label: detail.isCompound ? 'COMPOUND' : 'ISOLATION'),
              _InfoChip(label: detail.difficulty.toUpperCase()),
              _InfoChip(
                label: _formatLabel(detail.movementPattern).toUpperCase(),
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.xxl),

          _SectionTitle(
            title: showSecondaryMuscles ? 'TARGET MUSCLES' : 'TARGET MUSCLE',
          ),

          const SizedBox(height: ForgeSpacing.md),

          _MuscleVisualCard(
            name: detail.primaryMuscleName,
            assetPath: muscleVisualAssetFor(detail.primaryMuscleCode),
            role: 'PRIMARY TARGET',
            primary: true,
          ),

          if (showSecondaryMuscles && secondary.isNotEmpty) ...[
            const SizedBox(height: ForgeSpacing.xl),

            Text(
              'SECONDARY',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ForgeColors.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),

            const SizedBox(height: ForgeSpacing.md),

            SizedBox(
              height: 205,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: secondary.length,
                separatorBuilder: (_, _) {
                  return const SizedBox(width: ForgeSpacing.md);
                },
                itemBuilder: (context, index) {
                  final muscle = secondary[index];

                  return SizedBox(
                    width: 155,
                    child: _MuscleVisualCard(
                      name: muscle.name,
                      assetPath: muscleVisualAssetFor(muscle.code),
                      role: 'SECONDARY',
                      primary: false,
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: ForgeSpacing.xxl),

          _SectionTitle(
            title: hasPrescription ? 'PRESCRIPTION' : 'DEFAULT GUIDANCE',
          ),

          const SizedBox(height: ForgeSpacing.md),

          Container(
            padding: const EdgeInsets.all(ForgeSpacing.lg),
            decoration: BoxDecoration(
              color: ForgeColors.surface,
              borderRadius: BorderRadius.circular(ForgeRadius.lg),
              border: Border.all(color: ForgeColors.outline),
            ),
            child: hasPrescription
                ? Row(
                    children: [
                      Expanded(
                        child: _Metric(value: '$prescribedSets', label: 'SETS'),
                      ),
                      const _MetricDivider(),
                      Expanded(
                        child: _Metric(value: reps, label: 'REPS'),
                      ),
                      const _MetricDivider(),
                      Expanded(
                        child: _Metric(
                          value: '${effectiveRestSeconds}s',
                          label: 'REST',
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _Metric(value: reps, label: 'REPS'),
                      ),
                      const _MetricDivider(),
                      Expanded(
                        child: _Metric(
                          value: '${effectiveRestSeconds}s',
                          label: 'REST',
                        ),
                      ),
                    ],
                  ),
          ),

          if (detail.equipment.isNotEmpty) ...[
            const SizedBox(height: ForgeSpacing.xxl),

            const _SectionTitle(title: 'EQUIPMENT'),

            const SizedBox(height: ForgeSpacing.md),

            Wrap(
              spacing: ForgeSpacing.sm,
              runSpacing: ForgeSpacing.sm,
              children: [
                for (final item in detail.equipment)
                  _InfoChip(label: item.name.toUpperCase()),
              ],
            ),
          ],

          const SizedBox(height: ForgeSpacing.xl),

          Text(
            'Muscle visualization represents '
            'FORGE muscle groups.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: ForgeColors.textMuted),
          ),

          const SizedBox(height: ForgeSpacing.sm),

          Text(
            'Exercise data by RepDB (repdb.co)',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: ForgeColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.9),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ForgeColors.textSecondary,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _MuscleVisualCard extends StatelessWidget {
  const _MuscleVisualCard({
    required this.name,
    required this.assetPath,
    required this.role,
    required this.primary,
  });

  final String name;
  final String? assetPath;
  final String role;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.md),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(
          color: primary
              ? ForgeColors.primary.withValues(alpha: 0.32)
              : ForgeColors.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: primary ? 235 : 125,
            child: Center(
              child: assetPath == null
                  ? const Icon(
                      Icons.accessibility_new_rounded,
                      size: 64,
                      color: ForgeColors.textMuted,
                    )
                  : Image.asset(
                      assetPath!,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
            ),
          ),

          const SizedBox(height: ForgeSpacing.sm),

          Text(
            role,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: primary ? ForgeColors.primary : ForgeColors.textMuted,
              fontWeight: FontWeight.w900,
              fontSize: 9,
              letterSpacing: 0.7,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

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
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ForgeColors.textMuted,
            fontWeight: FontWeight.w800,
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
    return Container(width: 1, height: 36, color: ForgeColors.outline);
  }
}

String _formatLabel(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) {
        if (part.isEmpty) {
          return part;
        }

        return '${part[0].toUpperCase()}'
            '${part.substring(1).toLowerCase()}';
      })
      .join(' ');
}
