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

class WorkoutSetData {
  const WorkoutSetData({
    required this.id,
    required this.setNumber,
    required this.actualReps,
    required this.weightKg,
    required this.rpe,
    required this.isCompleted,
    required this.completedAt,
  });

  final String id;
  final int setNumber;

  final int? actualReps;
  final double? weightKg;
  final double? rpe;

  final bool isCompleted;
  final DateTime? completedAt;

  factory WorkoutSetData.fromJson(Map<String, dynamic> json) {
    return WorkoutSetData(
      id: json['id'] as String,
      setNumber: json['set_number'] as int,
      actualReps: json['actual_reps'] as int?,
      weightKg: _nullableDouble(json['weight_kg']),
      rpe: _nullableDouble(json['rpe']),
      isCompleted: json['is_completed'] as bool,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
    );
  }
}

class WorkoutExerciseData {
  const WorkoutExerciseData({
    required this.id,
    required this.programExerciseId,
    required this.exerciseId,
    required this.exerciseCode,
    required this.exerciseName,
    required this.exerciseOrder,
    required this.targetSets,
    required this.targetMinReps,
    required this.targetMaxReps,
    required this.targetRestSeconds,
    required this.status,
    required this.notes,
    required this.sets,
  });

  final String id;

  final String? programExerciseId;
  final String? exerciseId;

  final String exerciseCode;
  final String exerciseName;
  final int exerciseOrder;

  final int targetSets;
  final int targetMinReps;
  final int targetMaxReps;
  final int targetRestSeconds;

  final String status;
  final String? notes;

  final List<WorkoutSetData> sets;

  bool get isCompleted => status == 'completed';

  bool get isSkipped => status == 'skipped';

  bool get isPending => status == 'pending';

  int get completedSetCount {
    return sets.where((set) => set.isCompleted).length;
  }

  factory WorkoutExerciseData.fromJson(Map<String, dynamic> json) {
    return WorkoutExerciseData(
      id: json['id'] as String,
      programExerciseId: json['program_exercise_id'] as String?,
      exerciseId: json['exercise_id'] as String?,
      exerciseCode: json['exercise_code'] as String,
      exerciseName: json['exercise_name'] as String,
      exerciseOrder: json['exercise_order'] as int,
      targetSets: json['target_sets'] as int,
      targetMinReps: json['target_min_reps'] as int,
      targetMaxReps: json['target_max_reps'] as int,
      targetRestSeconds: json['target_rest_seconds'] as int,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      sets: (json['sets'] as List<dynamic>)
          .map(
            (item) =>
                WorkoutSetData.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
    );
  }
}

class WorkoutSessionData {
  const WorkoutSessionData({
    required this.id,
    required this.trainingProgramId,
    required this.programDayId,
    required this.programVersionNumber,
    required this.programName,
    required this.dayName,
    required this.dayOfWeek,
    required this.dayOrder,
    required this.status,
    required this.notes,
    required this.startedAt,
    required this.completedAt,
    required this.createdAt,
    required this.exercises,
  });

  final String id;

  final String? trainingProgramId;
  final String? programDayId;

  final int programVersionNumber;
  final String programName;

  final String dayName;
  final int dayOfWeek;
  final int dayOrder;

  final String status;
  final String? notes;

  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  final List<WorkoutExerciseData> exercises;

  bool get isInProgress => status == 'in_progress';

  int get totalSets {
    return exercises.fold(0, (total, exercise) => total + exercise.sets.length);
  }

  int get completedSets {
    return exercises.fold(
      0,
      (total, exercise) => total + exercise.completedSetCount,
    );
  }

  int get pendingExercises {
    return exercises.where((exercise) => exercise.isPending).length;
  }

  factory WorkoutSessionData.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionData(
      id: json['id'] as String,
      trainingProgramId: json['training_program_id'] as String?,
      programDayId: json['program_day_id'] as String?,
      programVersionNumber: json['program_version_number'] as int,
      programName: json['program_name'] as String,
      dayName: json['day_name'] as String,
      dayOfWeek: json['day_of_week'] as int,
      dayOrder: json['day_order'] as int,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      exercises: (json['exercises'] as List<dynamic>)
          .map(
            (item) => WorkoutExerciseData.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class WorkoutSummaryData {
  const WorkoutSummaryData({
    required this.id,
    required this.programVersionNumber,
    required this.programName,
    required this.dayName,
    required this.dayOfWeek,
    required this.dayOrder,
    required this.status,
    required this.startedAt,
    required this.completedAt,
  });

  final String id;

  final int programVersionNumber;
  final String programName;

  final String dayName;
  final int dayOfWeek;
  final int dayOrder;

  final String status;

  final DateTime startedAt;
  final DateTime? completedAt;

  factory WorkoutSummaryData.fromJson(Map<String, dynamic> json) {
    return WorkoutSummaryData(
      id: json['id'] as String,
      programVersionNumber: json['program_version_number'] as int,
      programName: json['program_name'] as String,
      dayName: json['day_name'] as String,
      dayOfWeek: json['day_of_week'] as int,
      dayOrder: json['day_order'] as int,
      status: json['status'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
    );
  }
}
