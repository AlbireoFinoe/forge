import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';
import '../../progress/presentation/exercise_progress_detail_screen.dart';
import '../data/adaptation_models.dart';
import 'adaptation_guidance.dart';

bool _needsMoreDataRecommendation(AdaptationRecommendationData recommendation) {
  return adaptationNeedsMoreData(recommendation);
}

int _needsMoreDataCount(AdaptationOverviewData overview) {
  return overview.recommendations.where(_needsMoreDataRecommendation).length;
}

int _genuineKeepCurrentCount(AdaptationOverviewData overview) {
  final needsMoreData = _needsMoreDataCount(overview);

  final remaining = overview.keepCurrent - needsMoreData;

  return remaining < 0 ? 0 : remaining;
}

String _emptyAdaptationMessage(AdaptationOverviewData overview) {
  final needsMoreData = _needsMoreDataCount(overview);

  final keepCurrent = _genuineKeepCurrentCount(overview);

  if (needsMoreData > 0 && keepCurrent > 0) {
    return 'Some exercises need more data. '
        'Others should stay at their '
        'current training load.';
  }

  if (needsMoreData > 0) {
    return 'Keep completing sessions and '
        'log RPE across all sets to unlock '
        'training adjustments.';
  }

  return 'No training changes are '
      'recommended right now.';
}

class AdaptationSection extends StatelessWidget {
  const AdaptationSection({
    required this.state,
    required this.onRetry,
    super.key,
  });

  final AsyncValue<AdaptationOverviewData> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () {
        return const _AdaptationLoading();
      },
      error: (error, stackTrace) {
        return _AdaptationError(onRetry: onRetry);
      },
      data: (overview) {
        if (overview.totalExercises == 0) {
          return const _AdaptationMessage(
            message:
                'Complete workouts to unlock '
                'training recommendations.',
          );
        }

        final actionable = overview.recommendations
            .where((item) => item.action != 'KEEP_CURRENT')
            .take(5)
            .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AdaptationSummary(overview: overview),

            const SizedBox(height: ForgeSpacing.md),

            if (actionable.isEmpty)
              _AdaptationMessage(message: _emptyAdaptationMessage(overview))
            else
              for (var index = 0; index < actionable.length; index++) ...[
                _AdaptationRow(recommendation: actionable[index]),

                if (index < actionable.length - 1)
                  const SizedBox(height: ForgeSpacing.sm),
              ],
          ],
        );
      },
    );
  }
}

class _AdaptationSummary extends StatelessWidget {
  const _AdaptationSummary({required this.overview});

  final AdaptationOverviewData overview;

  @override
  Widget build(BuildContext context) {
    final ready = overview.progressLoad + overview.progressReps;

    final needsMoreData = _needsMoreDataCount(overview);

    final keepCurrent = _genuineKeepCurrentCount(overview);

    final chips = <Widget>[];

    if (ready > 0) {
      chips.add(
        _CountChip(
          value: ready,
          label: 'READY TO PROGRESS',
          color: ForgeColors.success,
        ),
      );
    }

    if (overview.holdLoad > 0) {
      chips.add(
        _CountChip(
          value: overview.holdLoad,
          label: 'HOLD',
          color: ForgeColors.warning,
        ),
      );
    }

    if (overview.reduceStress > 0) {
      chips.add(
        _CountChip(
          value: overview.reduceStress,
          label: 'NEEDS ATTENTION',
          color: ForgeColors.error,
        ),
      );
    }

    if (needsMoreData > 0) {
      chips.add(
        _CountChip(
          value: needsMoreData,
          label: 'NEED MORE DATA',
          color: ForgeColors.textMuted,
        ),
      );
    }

    if (keepCurrent > 0) {
      chips.add(
        _CountChip(
          value: keepCurrent,
          label: 'KEEP CURRENT',
          color: ForgeColors.textSecondary,
        ),
      );
    }

    return Wrap(
      spacing: ForgeSpacing.sm,
      runSpacing: ForgeSpacing.sm,
      children: chips,
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ForgeSpacing.md,
        vertical: ForgeSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w900),
          ),

          const SizedBox(width: 5),

          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptationRow extends StatelessWidget {
  const _AdaptationRow({required this.recommendation});

  final AdaptationRecommendationData recommendation;

  @override
  Widget build(BuildContext context) {
    final presentation = adaptationPresentationFor(recommendation);

    final suggestion = adaptationSuggestionFor(recommendation);

    final reasons = recommendation.reasonCodes
        .take(2)
        .map(adaptationReasonLabel)
        .join(' \u2022 ');

    return Material(
      color: ForgeColors.surface,
      borderRadius: BorderRadius.circular(ForgeRadius.md),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) {
                return ExerciseProgressDetailScreen(
                  exerciseCode: recommendation.exerciseCode,
                  mode: ExerciseDetailMode.adaptation,
                );
              },
            ),
          );
        },
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        child: Container(
          padding: const EdgeInsets.all(ForgeSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ForgeRadius.md),
            border: Border.all(color: ForgeColors.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: presentation.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(ForgeRadius.sm),
                ),
                child: Icon(
                  presentation.icon,
                  size: 20,
                  color: presentation.color,
                ),
              ),

              const SizedBox(width: ForgeSpacing.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.exerciseName ??
                          recommendation.exerciseCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      presentation.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: presentation.color,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),

                    if (suggestion != null) ...[
                      const SizedBox(height: 5),

                      Text(
                        suggestion,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],

                    if (reasons.isNotEmpty) ...[
                      const SizedBox(height: 5),

                      Text(
                        reasons,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: ForgeColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: ForgeSpacing.sm),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    recommendation.confidence.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ForgeColors.textMuted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),

                  const SizedBox(width: 4),

                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: ForgeColors.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdaptationLoading extends StatelessWidget {
  const _AdaptationLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: const CircularProgressIndicator(),
    );
  }
}

class _AdaptationError extends StatelessWidget {
  const _AdaptationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: ForgeColors.textMuted),

          const SizedBox(width: ForgeSpacing.md),

          Expanded(
            child: Text(
              'Could not load adaptation '
              'guidance.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

          TextButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}

class _AdaptationMessage extends StatelessWidget {
  const _AdaptationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
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
            Icons.tune_rounded,
            size: 30,
            color: ForgeColors.textMuted,
          ),

          const SizedBox(height: ForgeSpacing.md),

          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: ForgeColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
