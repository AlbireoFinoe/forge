enum MusclePriorityLevel {
  maintenance(apiValue: 'maintenance', label: 'Maintenance'),
  normal(apiValue: 'normal', label: 'Normal'),
  high(apiValue: 'high', label: 'High');

  const MusclePriorityLevel({required this.apiValue, required this.label});

  final String apiValue;
  final String label;

  static MusclePriorityLevel fromApiValue(String value) {
    return MusclePriorityLevel.values.firstWhere(
      (priority) => priority.apiValue == value,
      orElse: () => throw FormatException('Unknown muscle priority: $value'),
    );
  }
}

class MuscleGroupData {
  const MuscleGroupData({
    required this.id,
    required this.code,
    required this.name,
    required this.region,
  });

  final String id;
  final String code;
  final String name;
  final String region;

  factory MuscleGroupData.fromJson(Map<String, dynamic> json) {
    return MuscleGroupData(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      region: json['region'] as String,
    );
  }
}

class MusclePriorityData {
  const MusclePriorityData({
    required this.muscleCode,
    required this.muscleName,
    required this.priority,
  });

  final String muscleCode;
  final String muscleName;
  final MusclePriorityLevel priority;

  factory MusclePriorityData.fromJson(Map<String, dynamic> json) {
    return MusclePriorityData(
      muscleCode: json['muscle_code'] as String,
      muscleName: json['muscle_name'] as String,
      priority: MusclePriorityLevel.fromApiValue(json['priority'] as String),
    );
  }
}

class MusclePrioritiesData {
  const MusclePrioritiesData({
    required this.muscleGroups,
    required this.savedPriorities,
  });

  final List<MuscleGroupData> muscleGroups;

  final Map<String, MusclePriorityLevel> savedPriorities;

  bool get isConfigured {
    if (muscleGroups.isEmpty) {
      return false;
    }

    return muscleGroups.every(
      (muscle) => savedPriorities.containsKey(muscle.code),
    );
  }

  MusclePriorityLevel priorityFor(String muscleCode) {
    return savedPriorities[muscleCode] ?? MusclePriorityLevel.normal;
  }
}
