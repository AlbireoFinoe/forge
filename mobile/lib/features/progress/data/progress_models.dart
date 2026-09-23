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

class ProgressOverviewItemData {
  const ProgressOverviewItemData({
    required this.exerciseCode,
    required this.exerciseName,
    required this.historyEntries,
    required this.completedSessions,
    required this.bestWeightKg,
    required this.latestTopWeightKg,
    required this.latestVolumeKg,
    required this.volumeChangePercent,
    required this.trend,
  });

  final String exerciseCode;
  final String exerciseName;

  final int historyEntries;
  final int completedSessions;

  final double? bestWeightKg;
  final double? latestTopWeightKg;
  final double? latestVolumeKg;

  final double? volumeChangePercent;

  final String trend;

  factory ProgressOverviewItemData.fromJson(Map<String, dynamic> json) {
    return ProgressOverviewItemData(
      exerciseCode: json['exercise_code'] as String,
      exerciseName: json['exercise_name'] as String,
      historyEntries: json['history_entries'] as int,
      completedSessions: json['completed_sessions'] as int,
      bestWeightKg: _nullableDouble(json['best_weight_kg']),
      latestTopWeightKg: _nullableDouble(json['latest_top_weight_kg']),
      latestVolumeKg: _nullableDouble(json['latest_volume_kg']),
      volumeChangePercent: _nullableDouble(json['volume_change_percent']),
      trend: json['trend'] as String,
    );
  }
}

class ProgressOverviewData {
  const ProgressOverviewData({
    required this.totalExercises,
    required this.improving,
    required this.stable,
    required this.declining,
    required this.insufficientData,
    required this.exercises,
  });

  final int totalExercises;

  final int improving;
  final int stable;
  final int declining;
  final int insufficientData;

  final List<ProgressOverviewItemData> exercises;

  factory ProgressOverviewData.fromJson(Map<String, dynamic> json) {
    return ProgressOverviewData(
      totalExercises: json['total_exercises'] as int,
      improving: json['improving'] as int,
      stable: json['stable'] as int,
      declining: json['declining'] as int,
      insufficientData: json['insufficient_data'] as int,
      exercises: (json['exercises'] as List<dynamic>)
          .map(
            (item) => ProgressOverviewItemData.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}
