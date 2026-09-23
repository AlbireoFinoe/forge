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

class ExerciseProgressData {
  const ExerciseProgressData({
    required this.exerciseCode,
    required this.exerciseName,
    required this.historyEntries,
    required this.completedSessions,
    required this.bestWeightKg,
    required this.bestWeightReps,
    required this.bestSessionVolumeKg,
    required this.latestTopWeightKg,
    required this.latestVolumeKg,
    required this.latestAverageRpe,
    required this.previousTopWeightKg,
    required this.previousVolumeKg,
    required this.previousAverageRpe,
    required this.volumeChangePercent,
    required this.trend,
  });

  final String exerciseCode;
  final String exerciseName;

  final int historyEntries;
  final int completedSessions;

  final double? bestWeightKg;
  final int? bestWeightReps;

  final double bestSessionVolumeKg;

  final double? latestTopWeightKg;
  final double? latestVolumeKg;
  final double? latestAverageRpe;

  final double? previousTopWeightKg;
  final double? previousVolumeKg;
  final double? previousAverageRpe;

  final double? volumeChangePercent;
  final String trend;

  factory ExerciseProgressData.fromJson(Map<String, dynamic> json) {
    return ExerciseProgressData(
      exerciseCode: json['exercise_code'] as String,
      exerciseName: json['exercise_name'] as String,
      historyEntries: json['history_entries'] as int,
      completedSessions: json['completed_sessions'] as int,
      bestWeightKg: _nullableDouble(json['best_weight_kg']),
      bestWeightReps: json['best_weight_reps'] as int?,
      bestSessionVolumeKg: _nullableDouble(json['best_session_volume_kg']) ?? 0,
      latestTopWeightKg: _nullableDouble(json['latest_top_weight_kg']),
      latestVolumeKg: _nullableDouble(json['latest_volume_kg']),
      latestAverageRpe: _nullableDouble(json['latest_average_rpe']),
      previousTopWeightKg: _nullableDouble(json['previous_top_weight_kg']),
      previousVolumeKg: _nullableDouble(json['previous_volume_kg']),
      previousAverageRpe: _nullableDouble(json['previous_average_rpe']),
      volumeChangePercent: _nullableDouble(json['volume_change_percent']),
      trend: json['trend'] as String,
    );
  }
}

class ExerciseHistoryItemData {
  const ExerciseHistoryItemData({
    required this.workoutId,
    required this.workoutCompletedAt,
    required this.exerciseCode,
    required this.exerciseName,
    required this.exerciseStatus,
    required this.targetSets,
    required this.completedSets,
    required this.setCompletionRate,
    required this.totalReps,
    required this.topWeightKg,
    required this.externalVolumeKg,
    required this.averageRpe,
  });

  final String workoutId;
  final DateTime workoutCompletedAt;

  final String exerciseCode;
  final String exerciseName;
  final String exerciseStatus;

  final int targetSets;
  final int completedSets;
  final double setCompletionRate;

  final int totalReps;

  final double? topWeightKg;
  final double externalVolumeKg;
  final double? averageRpe;

  factory ExerciseHistoryItemData.fromJson(Map<String, dynamic> json) {
    return ExerciseHistoryItemData(
      workoutId: json['workout_id'] as String,
      workoutCompletedAt: DateTime.parse(
        json['workout_completed_at'] as String,
      ),
      exerciseCode: json['exercise_code'] as String,
      exerciseName: json['exercise_name'] as String,
      exerciseStatus: json['exercise_status'] as String,
      targetSets: json['target_sets'] as int,
      completedSets: json['completed_sets'] as int,
      setCompletionRate: (json['set_completion_rate'] as num).toDouble(),
      totalReps: json['total_reps'] as int,
      topWeightKg: _nullableDouble(json['top_weight_kg']),
      externalVolumeKg: _nullableDouble(json['external_volume_kg']) ?? 0,
      averageRpe: _nullableDouble(json['average_rpe']),
    );
  }
}
