double? _nullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.parse(value);
  }

  throw FormatException('Expected numeric value, got $value');
}

class AdaptationRecommendationData {
  const AdaptationRecommendationData({
    required this.exerciseCode,
    required this.exerciseName,
    required this.action,
    required this.confidence,
    required this.reasonCodes,
    required this.completedSessions,
    required this.trend,
    required this.latestWeightKg,
    required this.latestAverageRpe,
    required this.volumeChangePercent,
    required this.suggestedLoadChangePercent,
    required this.suggestedRepChange,
    required this.suggestedSetChange,
  });

  final String exerciseCode;
  final String? exerciseName;

  final String action;
  final String confidence;

  final List<String> reasonCodes;

  final int completedSessions;
  final String trend;

  final double? latestWeightKg;
  final double? latestAverageRpe;
  final double? volumeChangePercent;

  final double? suggestedLoadChangePercent;
  final int? suggestedRepChange;
  final int? suggestedSetChange;

  factory AdaptationRecommendationData.fromJson(Map<String, dynamic> json) {
    return AdaptationRecommendationData(
      exerciseCode: json['exercise_code'] as String,
      exerciseName: json['exercise_name'] as String?,
      action: json['action'] as String,
      confidence: json['confidence'] as String,
      reasonCodes: (json['reason_codes'] as List<dynamic>)
          .map((item) => item as String)
          .toList(growable: false),
      completedSessions: json['completed_sessions'] as int,
      trend: json['trend'] as String,
      latestWeightKg: _nullableDouble(json['latest_weight_kg']),
      latestAverageRpe: _nullableDouble(json['latest_average_rpe']),
      volumeChangePercent: _nullableDouble(json['volume_change_percent']),
      suggestedLoadChangePercent: _nullableDouble(
        json['suggested_load_change_percent'],
      ),
      suggestedRepChange: json['suggested_rep_change'] as int?,
      suggestedSetChange: json['suggested_set_change'] as int?,
    );
  }
}

class AdaptationOverviewData {
  const AdaptationOverviewData({
    required this.totalExercises,
    required this.progressLoad,
    required this.progressReps,
    required this.holdLoad,
    required this.keepCurrent,
    required this.reduceStress,
    required this.recommendations,
  });

  final int totalExercises;

  final int progressLoad;
  final int progressReps;
  final int holdLoad;
  final int keepCurrent;
  final int reduceStress;

  final List<AdaptationRecommendationData> recommendations;

  factory AdaptationOverviewData.fromJson(Map<String, dynamic> json) {
    return AdaptationOverviewData(
      totalExercises: json['total_exercises'] as int,
      progressLoad: json['progress_load'] as int,
      progressReps: json['progress_reps'] as int,
      holdLoad: json['hold_load'] as int,
      keepCurrent: json['keep_current'] as int,
      reduceStress: json['reduce_stress'] as int,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map(
            (item) => AdaptationRecommendationData.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}
