import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';
import '../../adaptation/data/adaptation_models.dart';
import '../../adaptation/presentation/adaptation_guidance.dart';
import '../../adaptation/presentation/adaptation_provider.dart';
import '../data/progress_models.dart';
import 'progress_provider.dart';

class ExerciseProgressDetailScreen extends ConsumerWidget {
  const ExerciseProgressDetailScreen({required this.exerciseCode, super.key});

  final String exerciseCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressState = ref.watch(exerciseProgressProvider(exerciseCode));

    final historyState = ref.watch(
      exerciseProgressHistoryProvider(exerciseCode),
    );

    final adaptationState = ref.watch(exerciseAdaptationProvider(exerciseCode));

    return Scaffold(
      appBar: AppBar(title: const Text('EXERCISE PROGRESS')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(exerciseProgressProvider(exerciseCode));

          ref.invalidate(exerciseProgressHistoryProvider(exerciseCode));

          ref.invalidate(exerciseAdaptationProvider(exerciseCode));

          await Future.wait([
            ref.read(exerciseProgressProvider(exerciseCode).future),
            ref.read(exerciseProgressHistoryProvider(exerciseCode).future),
          ]);
        },
        child: progressState.when(
          loading: () {
            return const _DetailLoading();
          },
          error: (error, stackTrace) {
            return _DetailError(
              onRetry: () {
                ref.invalidate(exerciseProgressProvider(exerciseCode));
              },
            );
          },
          data: (progress) {
            return _DetailContent(
              progress: progress,
              historyState: historyState,
              adaptationState: adaptationState,
              onRetryAdaptation: () {
                ref.invalidate(exerciseAdaptationProvider(exerciseCode));
              },
            );
          },
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.progress,
    required this.historyState,
    required this.adaptationState,
    required this.onRetryAdaptation,
  });

  final ExerciseProgressData progress;

  final AsyncValue<List<ExerciseHistoryItemData>> historyState;

  final AsyncValue<AdaptationRecommendationData> adaptationState;

  final VoidCallback onRetryAdaptation;

  @override
  Widget build(BuildContext context) {
    final trend = _trendPresentation(progress.trend);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        ForgeSpacing.xl,
        ForgeSpacing.lg,
        ForgeSpacing.xl,
        ForgeSpacing.xxl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          progress.exerciseName,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 6),

        Text(
          _progressSessionSummary(progress),
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: ForgeColors.textSecondary),
        ),

        const SizedBox(height: ForgeSpacing.xl),

        _TrendCard(progress: progress, presentation: trend),

        const SizedBox(height: ForgeSpacing.xxl),

        const _SectionTitle(title: 'NEXT SESSION'),

        const SizedBox(height: ForgeSpacing.md),

        _NextSessionGuidance(
          state: adaptationState,
          onRetry: onRetryAdaptation,
        ),

        const SizedBox(height: ForgeSpacing.xxl),

        const _SectionTitle(title: 'LATEST'),

        const SizedBox(height: ForgeSpacing.md),

        _LatestCard(progress: progress, historyState: historyState),

        const SizedBox(height: ForgeSpacing.xxl),

        const _SectionTitle(title: 'PERSONAL BEST'),

        const SizedBox(height: ForgeSpacing.md),

        _PersonalBestCard(progress: progress),

        const SizedBox(height: ForgeSpacing.xxl),

        const _SectionTitle(title: 'RECENT SESSIONS'),

        const SizedBox(height: ForgeSpacing.md),

        _HistorySection(state: historyState),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.progress, required this.presentation});

  final ExerciseProgressData progress;
  final _TrendPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final change = progress.volumeChangePercent;

    String description;

    if (progress.trend == 'insufficient_data') {
      description =
          'Complete another session '
          'to establish a trend.';
    } else if (change != null) {
      description =
          '${_signedPercent(change)} '
          'volume vs previous session';
    } else {
      description =
          'Compared with your previous '
          'completed session.';
    }

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.xl),
      decoration: BoxDecoration(
        color: ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: presentation.color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: presentation.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(ForgeRadius.md),
            ),
            child: Icon(presentation.icon, color: presentation.color),
          ),

          const SizedBox(width: ForgeSpacing.lg),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: presentation.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ForgeColors.textSecondary,
                    height: 1.35,
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

class _NextSessionGuidance extends StatelessWidget {
  const _NextSessionGuidance({required this.state, required this.onRetry});

  final AsyncValue<AdaptationRecommendationData> state;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () {
        return Container(
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ForgeColors.surface,
            borderRadius: BorderRadius.circular(ForgeRadius.lg),
            border: Border.all(color: ForgeColors.outline),
          ),
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      error: (error, stackTrace) {
        return Container(
          padding: const EdgeInsets.all(ForgeSpacing.lg),
          decoration: BoxDecoration(
            color: ForgeColors.surface,
            borderRadius: BorderRadius.circular(ForgeRadius.lg),
            border: Border.all(color: ForgeColors.outline),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: ForgeColors.textMuted,
              ),
              const SizedBox(width: ForgeSpacing.md),
              Expanded(
                child: Text(
                  'Next-session guidance '
                  'is unavailable.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('RETRY')),
            ],
          ),
        );
      },
      data: (recommendation) {
        final presentation = adaptationPresentationFor(recommendation);

        final suggestion = adaptationSuggestionFor(recommendation);

        final reasons = recommendation.reasonCodes
            .take(2)
            .map(adaptationReasonLabel)
            .join(' \u2022 ');

        return Container(
          padding: const EdgeInsets.all(ForgeSpacing.lg),
          decoration: BoxDecoration(
            color: ForgeColors.surface,
            borderRadius: BorderRadius.circular(ForgeRadius.lg),
            border: Border.all(
              color: presentation.color.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: presentation.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(ForgeRadius.md),
                ),
                child: Icon(
                  presentation.icon,
                  color: presentation.color,
                  size: 21,
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
                            presentation.label,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: presentation.color,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                          ),
                        ),
                        Text(
                          recommendation.confidence.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: ForgeColors.textMuted,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ],
                    ),
                    if (suggestion != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        suggestion,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                    if (reasons.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        reasons,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ForgeColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LatestCard extends StatelessWidget {
  const _LatestCard({required this.progress, required this.historyState});

  final ExerciseProgressData progress;

  final AsyncValue<List<ExerciseHistoryItemData>> historyState;

  @override
  Widget build(BuildContext context) {
    final latest = historyState.maybeWhen(
      data: (items) {
        if (items.isEmpty) {
          return null;
        }

        return items.first;
      },
      orElse: () {
        return null;
      },
    );

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: progress.latestTopWeightKg == null
                      ? '\u2014'
                      : '${_formatNumber(progress.latestTopWeightKg!)} kg',
                  label: 'TOP WEIGHT',
                ),
              ),

              const _MetricDivider(),

              Expanded(
                child: _Metric(
                  value: latest == null ? '\u2014' : '${latest.totalReps}',
                  label: 'TOTAL REPS',
                ),
              ),
            ],
          ),

          const SizedBox(height: ForgeSpacing.lg),

          Row(
            children: [
              Expanded(
                child: _Metric(
                  value:
                      progress.latestVolumeKg == null ||
                          progress.latestVolumeKg == 0
                      ? '\u2014'
                      : '${_formatNumber(progress.latestVolumeKg!)} kg',
                  label: 'VOLUME',
                ),
              ),

              const _MetricDivider(),

              Expanded(
                child: _Metric(
                  value: progress.latestAverageRpe == null
                      ? '\u2014'
                      : _formatNumber(progress.latestAverageRpe!),
                  label: 'AVG RPE',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonalBestCard extends StatelessWidget {
  const _PersonalBestCard({required this.progress});

  final ExerciseProgressData progress;

  @override
  Widget build(BuildContext context) {
    final hasWeight = progress.bestWeightKg != null;

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.xl),
      decoration: BoxDecoration(
        color: ForgeColors.surfaceRaised,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.primary.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasWeight
                ? '${_formatNumber(progress.bestWeightKg!)} kg'
                      '${progress.bestWeightReps == null ? '' : ' \u00d7 ${progress.bestWeightReps}'}'
                : 'No load recorded',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 5),

          Text(
            hasWeight
                ? 'Heaviest completed set'
                : 'Weight-based personal best '
                      'is not available yet.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: ForgeColors.textSecondary),
          ),

          if (progress.bestSessionVolumeKg > 0) ...[
            const SizedBox(height: ForgeSpacing.lg),

            const Divider(height: 1, color: ForgeColors.outline),

            const SizedBox(height: ForgeSpacing.lg),

            Row(
              children: [
                Text(
                  'BEST SESSION VOLUME',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ForgeColors.textMuted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),

                const Spacer(),

                Text(
                  '${_formatNumber(progress.bestSessionVolumeKg)} kg',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.state});

  final AsyncValue<List<ExerciseHistoryItemData>> state;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () {
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, stackTrace) {
        return _MessageCard(
          message:
              'Could not load recent '
              'exercise sessions.',
        );
      },
      data: (history) {
        if (history.isEmpty) {
          return const _MessageCard(message: 'No completed sessions yet.');
        }

        final visible = history.take(8).toList(growable: false);

        return Column(
          children: [
            for (var index = 0; index < visible.length; index++) ...[
              _HistoryRow(item: visible[index]),

              if (index < visible.length - 1)
                const SizedBox(height: ForgeSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final ExerciseHistoryItemData item;

  @override
  Widget build(BuildContext context) {
    final local = item.workoutCompletedAt.toLocal();

    final details = <String>[
      '${item.completedSets}/'
          '${item.targetSets} sets',
      '${item.totalReps} reps',
    ];

    if (item.topWeightKg != null) {
      details.add('${_formatNumber(item.topWeightKg!)} kg');
    }

    if (item.averageRpe != null) {
      details.add(
        'RPE '
        '${_formatNumber(item.averageRpe!)}',
      );
    }

    return Container(
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.md),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monthLabel(local.month).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ForgeColors.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                Text(
                  '${local.day}',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),

          const SizedBox(width: ForgeSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.join(' \u2022 '),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),

                if (item.externalVolumeKg > 0) ...[
                  const SizedBox(height: 4),

                  Text(
                    '${_formatNumber(item.externalVolumeKg)} kg volume',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: ForgeColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ForgeSpacing.lg),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(ForgeRadius.lg),
        border: Border.all(color: ForgeColors.outline),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: ForgeColors.textSecondary),
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
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ForgeColors.textMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
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
    return Container(width: 1, height: 40, color: ForgeColors.outline);
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
          ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.8),
    );
  }
}

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 240),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(ForgeSpacing.xl),
      children: [
        const SizedBox(height: 120),
        const Icon(
          Icons.cloud_off_outlined,
          size: 44,
          color: ForgeColors.textMuted,
        ),
        const SizedBox(height: ForgeSpacing.lg),
        Text(
          'Could not load '
          'exercise progress',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: ForgeSpacing.lg),
        FilledButton(onPressed: onRetry, child: const Text('RETRY')),
      ],
    );
  }
}

class _TrendPresentation {
  const _TrendPresentation({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

_TrendPresentation _trendPresentation(String trend) {
  switch (trend) {
    case 'improving':
      return const _TrendPresentation(
        label: 'IMPROVING',
        icon: Icons.trending_up_rounded,
        color: ForgeColors.success,
      );

    case 'declining':
      return const _TrendPresentation(
        label: 'DECLINING',
        icon: Icons.trending_down_rounded,
        color: ForgeColors.error,
      );

    case 'stable':
      return const _TrendPresentation(
        label: 'STABLE',
        icon: Icons.trending_flat_rounded,
        color: ForgeColors.textSecondary,
      );

    default:
      return const _TrendPresentation(
        label: 'MORE DATA',
        icon: Icons.more_horiz_rounded,
        color: ForgeColors.textMuted,
      );
  }
}

String _signedPercent(double value) {
  final sign = value > 0 ? '+' : '';

  return '$sign'
      '${_formatNumber(value)}%';
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(1);
}

String _monthLabel(int month) {
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

  return months[month - 1];
}

String _progressSessionSummary(ExerciseProgressData progress) {
  final logged = progress.historyEntries;

  final loggedLabel =
      '$logged logged '
      '${logged == 1 ? 'session' : 'sessions'}';

  if (progress.completedSessions == progress.historyEntries) {
    return loggedLabel;
  }

  final completed = progress.completedSessions;

  return '$loggedLabel ? '
      '$completed fully completed';
}
