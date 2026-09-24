import 'package:flutter/material.dart';

import '../../../core/theme/forge_theme.dart';
import '../data/adaptation_models.dart';

const adaptationMoreDataReasonCodes = <String>{
  'INSUFFICIENT_DATA',
  'INSUFFICIENT_COMPLETED_SESSIONS',
  'MISSING_RPE_DATA',
};

bool adaptationNeedsMoreData(AdaptationRecommendationData recommendation) {
  return recommendation.action == 'KEEP_CURRENT' &&
      recommendation.reasonCodes.any(adaptationMoreDataReasonCodes.contains);
}

class AdaptationPresentation {
  const AdaptationPresentation({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

AdaptationPresentation adaptationPresentationFor(
  AdaptationRecommendationData item,
) {
  if (adaptationNeedsMoreData(item)) {
    return const AdaptationPresentation(
      label: 'NEED MORE DATA',
      icon: Icons.more_horiz_rounded,
      color: ForgeColors.textMuted,
    );
  }

  switch (item.action) {
    case 'PROGRESS_LOAD':
      return const AdaptationPresentation(
        label: 'INCREASE LOAD',
        icon: Icons.trending_up_rounded,
        color: ForgeColors.success,
      );

    case 'PROGRESS_REPS':
      return const AdaptationPresentation(
        label: 'ADD REPS',
        icon: Icons.add_rounded,
        color: ForgeColors.success,
      );

    case 'HOLD_LOAD':
      return const AdaptationPresentation(
        label: 'HOLD LOAD',
        icon: Icons.pause_rounded,
        color: ForgeColors.warning,
      );

    case 'REDUCE_STRESS':
      return const AdaptationPresentation(
        label: 'REDUCE STRESS',
        icon: Icons.south_rounded,
        color: ForgeColors.error,
      );

    default:
      return const AdaptationPresentation(
        label: 'KEEP CURRENT',
        icon: Icons.horizontal_rule_rounded,
        color: ForgeColors.textSecondary,
      );
  }
}

String? adaptationSuggestionFor(AdaptationRecommendationData item) {
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

  if (parts.isNotEmpty) {
    return '${parts.join(' \u2022 ')} '
        'next session';
  }

  if (item.action == 'HOLD_LOAD') {
    return 'Keep your current load '
        'next session';
  }

  if (item.action == 'KEEP_CURRENT' && adaptationNeedsMoreData(item)) {
    if (item.reasonCodes.contains('MISSING_RPE_DATA')) {
      return 'Log RPE across all sets '
          'next session';
    }

    if (item.reasonCodes.contains('INSUFFICIENT_COMPLETED_SESSIONS')) {
      return 'Complete another full session '
          'to build a reliable signal';
    }

    return 'Keep logging complete sessions '
        'to build a reliable signal';
  }

  if (item.action == 'KEEP_CURRENT') {
    return 'Maintain your current training '
        'load next session';
  }

  return null;
}

String adaptationReasonLabel(String code) {
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
