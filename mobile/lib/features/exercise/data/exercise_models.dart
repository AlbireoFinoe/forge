class ExerciseEquipmentData {
  const ExerciseEquipmentData({required this.code, required this.name});

  final String code;
  final String name;

  factory ExerciseEquipmentData.fromJson(Map<String, dynamic> json) {
    return ExerciseEquipmentData(
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }
}

class ExerciseSecondaryMuscleData {
  const ExerciseSecondaryMuscleData({
    required this.code,
    required this.name,
    required this.contributionWeight,
  });

  final String code;
  final String name;
  final double contributionWeight;

  factory ExerciseSecondaryMuscleData.fromJson(Map<String, dynamic> json) {
    return ExerciseSecondaryMuscleData(
      code: json['code'] as String,
      name: json['name'] as String,
      contributionWeight: (json['contribution_weight'] as num).toDouble(),
    );
  }
}

class ExerciseDetailData {
  const ExerciseDetailData({
    required this.id,
    required this.code,
    required this.name,
    required this.primaryMuscleCode,
    required this.primaryMuscleName,
    required this.movementPattern,
    required this.difficulty,
    required this.isCompound,
    required this.minReps,
    required this.maxReps,
    required this.restSeconds,
    required this.equipment,
    required this.secondaryMuscles,
  });

  final String id;
  final String code;
  final String name;

  final String primaryMuscleCode;
  final String primaryMuscleName;

  final String movementPattern;
  final String difficulty;
  final bool isCompound;

  final int minReps;
  final int maxReps;
  final int restSeconds;

  final List<ExerciseEquipmentData> equipment;

  final List<ExerciseSecondaryMuscleData> secondaryMuscles;

  factory ExerciseDetailData.fromJson(Map<String, dynamic> json) {
    return ExerciseDetailData(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      primaryMuscleCode: json['primary_muscle_code'] as String,
      primaryMuscleName: json['primary_muscle_name'] as String,
      movementPattern: json['movement_pattern'] as String,
      difficulty: json['difficulty'] as String,
      isCompound: json['is_compound'] as bool,
      minReps: json['min_reps'] as int,
      maxReps: json['max_reps'] as int,
      restSeconds: json['rest_seconds'] as int,
      equipment: (json['equipment'] as List<dynamic>)
          .map(
            (item) => ExerciseEquipmentData.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      secondaryMuscles: (json['secondary_muscles'] as List<dynamic>)
          .map(
            (item) => ExerciseSecondaryMuscleData.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}
