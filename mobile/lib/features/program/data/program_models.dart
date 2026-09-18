class ProgramWarningData {
  const ProgramWarningData({required this.code, required this.message});

  final String code;
  final String message;

  factory ProgramWarningData.fromJson(Map<String, dynamic> json) {
    return ProgramWarningData(
      code: json['code'] as String,
      message: json['message'] as String,
    );
  }
}

class ProgramGenerateData {
  const ProgramGenerateData({
    required this.id,
    required this.name,
    required this.versionNumber,
    required this.generatorVersion,
    required this.setupRevision,
    required this.currentSetupRevision,
    required this.isOutdated,
    required this.goal,
    required this.status,
    required this.validationPassed,
    required this.programDays,
    required this.programExercises,
    required this.warnings,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int versionNumber;
  final String generatorVersion;
  final int setupRevision;
  final int currentSetupRevision;
  final bool isOutdated;
  final String goal;
  final String status;
  final bool validationPassed;
  final int programDays;
  final int programExercises;
  final List<ProgramWarningData> warnings;
  final DateTime createdAt;

  factory ProgramGenerateData.fromJson(Map<String, dynamic> json) {
    return ProgramGenerateData(
      id: json['id'] as String,
      name: json['name'] as String,
      versionNumber: json['version_number'] as int,
      generatorVersion: json['generator_version'] as String,
      setupRevision: json['setup_revision'] as int,
      currentSetupRevision: json['current_setup_revision'] as int,
      isOutdated: json['is_outdated'] as bool,
      goal: json['goal'] as String,
      status: json['status'] as String,
      validationPassed: json['validation_passed'] as bool,
      programDays: json['program_days'] as int,
      programExercises: json['program_exercises'] as int,
      warnings: (json['warnings'] as List<dynamic>)
          .map(
            (item) => ProgramWarningData.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ProgramExerciseData {
  const ProgramExerciseData({
    required this.id,
    required this.exerciseId,
    required this.exerciseCode,
    required this.exerciseName,
    required this.exerciseOrder,
    required this.sets,
    required this.minReps,
    required this.maxReps,
    required this.restSeconds,
    required this.reasonCodes,
  });

  final String id;
  final String exerciseId;
  final String exerciseCode;
  final String exerciseName;
  final int exerciseOrder;
  final int sets;
  final int minReps;
  final int maxReps;
  final int restSeconds;
  final List<String> reasonCodes;

  factory ProgramExerciseData.fromJson(Map<String, dynamic> json) {
    return ProgramExerciseData(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseCode: json['exercise_code'] as String,
      exerciseName: json['exercise_name'] as String,
      exerciseOrder: json['exercise_order'] as int,
      sets: json['sets'] as int,
      minReps: json['min_reps'] as int,
      maxReps: json['max_reps'] as int,
      restSeconds: json['rest_seconds'] as int,
      reasonCodes: (json['reason_codes'] as List<dynamic>).cast<String>(),
    );
  }
}

class ProgramDayData {
  const ProgramDayData({
    required this.id,
    required this.dayOfWeek,
    required this.dayOrder,
    required this.name,
    required this.estimatedDurationMinutes,
    required this.exercises,
  });

  final String id;
  final int dayOfWeek;
  final int dayOrder;
  final String name;
  final int estimatedDurationMinutes;
  final List<ProgramExerciseData> exercises;

  factory ProgramDayData.fromJson(Map<String, dynamic> json) {
    return ProgramDayData(
      id: json['id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      dayOrder: json['day_order'] as int,
      name: json['name'] as String,
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int,
      exercises: (json['exercises'] as List<dynamic>)
          .map(
            (item) => ProgramExerciseData.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class ProgramDetailData {
  const ProgramDetailData({
    required this.id,
    required this.name,
    required this.versionNumber,
    required this.generatorVersion,
    required this.setupRevision,
    required this.currentSetupRevision,
    required this.isOutdated,
    required this.goal,
    required this.status,
    required this.createdAt,
    required this.days,
  });

  final String id;
  final String name;
  final int versionNumber;
  final String generatorVersion;
  final int setupRevision;
  final int currentSetupRevision;
  final bool isOutdated;
  final String goal;
  final String status;
  final DateTime createdAt;
  final List<ProgramDayData> days;

  int get totalExercises {
    return days.fold(0, (total, day) => total + day.exercises.length);
  }

  factory ProgramDetailData.fromJson(Map<String, dynamic> json) {
    return ProgramDetailData(
      id: json['id'] as String,
      name: json['name'] as String,
      versionNumber: json['version_number'] as int,
      generatorVersion: json['generator_version'] as String,
      setupRevision: json['setup_revision'] as int,
      currentSetupRevision: json['current_setup_revision'] as int,
      isOutdated: json['is_outdated'] as bool,
      goal: json['goal'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      days: (json['days'] as List<dynamic>)
          .map(
            (item) =>
                ProgramDayData.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
    );
  }
}

class ProgramSummaryData {
  const ProgramSummaryData({
    required this.id,
    required this.name,
    required this.versionNumber,
    required this.generatorVersion,
    required this.setupRevision,
    required this.currentSetupRevision,
    required this.isOutdated,
    required this.goal,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int versionNumber;
  final String generatorVersion;
  final int setupRevision;
  final int currentSetupRevision;
  final bool isOutdated;
  final String goal;
  final String status;
  final DateTime createdAt;

  factory ProgramSummaryData.fromJson(Map<String, dynamic> json) {
    return ProgramSummaryData(
      id: json['id'] as String,
      name: json['name'] as String,
      versionNumber: json['version_number'] as int,
      generatorVersion: json['generator_version'] as String,
      setupRevision: json['setup_revision'] as int,
      currentSetupRevision: json['current_setup_revision'] as int,
      isOutdated: json['is_outdated'] as bool,
      goal: json['goal'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
