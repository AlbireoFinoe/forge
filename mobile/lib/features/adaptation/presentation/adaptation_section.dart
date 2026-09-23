import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';
import '../../progress/presentation/exercise_progress_detail_screen.dart';
import '../data/adaptation_models.dart';

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

        final needsMoreData = overview.recommendations.any(
          (item) =>
              item.reasonCodes.contains('INSUFFICIENT_DATA') ||
              item.reasonCodes.contains('INSUFFICIENT_COMPLETED_SESSIONS') ||
              item.reasonCodes.contains('MISSING_RPE_DATA'),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AdaptationSummary(overview: overview),

            const SizedBox(height: ForgeSpacing.md),

            if (actionable.isEmpty)
              _AdaptationMessage(
                message: needsMoreData
                    ? 'Keep logging workouts and RPE '
                          'to build stronger adaptation '
                          'signals.'
                    : 'No training changes are '
                          'recommended right now.',
              )
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

    if (chips.isEmpty) {
      chips.add(
        _CountChip(
          value: overview.keepCurrent,
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
    final presentation = _presentationFor(recommendation.action);

    final suggestion = _suggestionFor(recommendation);

    final reasons = recommendation.reasonCodes
        .take(2)
        .map(_reasonLabel)
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

class _Presentation {
  const _Presentation({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

_Presentation _presentationFor(String action) {
  switch (action) {
    case 'PROGRESS_LOAD':
      return const _Presentation(
        label: 'INCREASE LOAD',
        icon: Icons.trending_up_rounded,
        color: ForgeColors.success,
      );

    case 'PROGRESS_REPS':
      return const _Presentation(
        label: 'ADD REPS',
        icon: Icons.add_rounded,
        color: ForgeColors.success,
      );

    case 'HOLD_LOAD':
      return const _Presentation(
        label: 'HOLD LOAD',
        icon: Icons.pause_rounded,
        color: ForgeColors.warning,
      );

    case 'REDUCE_STRESS':
      return const _Presentation(
        label: 'REDUCE STRESS',
        icon: Icons.south_rounded,
        color: ForgeColors.error,
      );

    default:
      return const _Presentation(
        label: 'KEEP CURRENT',
        icon: Icons.horizontal_rule_rounded,
        color: ForgeColors.textSecondary,
      );
  }
}

String? _suggestionFor(AdaptationRecommendationData item) {
  final parts = <String>[];

  final load = item.suggestedLoadChangePercent;

  if (load != null && load != 0) {
    parts.add('${_signedDouble(load)}% load');
  }

  final reps = item.suggestedRepChange;

  if (reps != null && reps != 0) {
    parts.add(
      '${_signedInt(reps)} '
      '${reps.abs() == 1 ? 'rep' : 'reps'}',
    );
  }

  final sets = item.suggestedSetChange;

  if (sets != null && sets != 0) {
    parts.add(
      '${_signedInt(sets)} '
      '${sets.abs() == 1 ? 'set' : 'sets'}',
    );
  }

  if (parts.isEmpty) {
    if (item.action == 'HOLD_LOAD') {
      return 'Keep your current load '
          'next session';
    }

    return null;
  }

  return '${parts.join(' \u2022 ')} '
      'next session';
}

String _reasonLabel(String code) {
  const labels = {
    'PERFORMANCE_IMPROVING': 'Performance improving',
    'RPE_MANAGEABLE': 'RPE manageable',
    'NO_EXTERNAL_LOAD': 'No external load',
    'RPE_HIGH': 'High RPE',
    'PERFORMANCE_STABLE': 'Performance stable',
    'RPE_LOW': 'Low RPE',
    'RPE_MODERATE_OR_HIGH': 'Moderate or high RPE',
    'PERFORMANCE_DECLINING': 'Performance declining',
    'REVIEW_BEFORE_REDUCTION': 'Review before reduction',
    'INSUFFICIENT_DATA': 'More data needed',
    'INSUFFICIENT_COMPLETED_SESSIONS': 'More sessions needed',
    'MISSING_RPE_DATA': 'RPE data needed',
  };

  return labels[code] ??
      code
          .toLowerCase()
          .split('_')
          .map((part) {
            if (part.isEmpty) {
              return '';
            }

            return '${part[0].toUpperCase()}'
                '${part.substring(1)}';
          })
          .join(' ');
}

String _signedInt(int value) {
  return value > 0 ? '+$value' : '$value';
}

String _signedDouble(double value) {
  final formatted = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  return value > 0 ? '+$formatted' : formatted;
}
