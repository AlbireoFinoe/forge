enum TrainingGoal {
  muscleGain(
    apiValue: 'muscle_gain',
    label: 'Muscle Gain',
    description: 'Build muscle size and overall muscular development.',
  ),
  strength(
    apiValue: 'strength',
    label: 'Strength',
    description: 'Focus on getting stronger in your major lifts.',
  ),
  fatLoss(
    apiValue: 'fat_loss',
    label: 'Fat Loss',
    description: 'Support fat loss while maintaining training performance.',
  ),
  generalFitness(
    apiValue: 'general_fitness',
    label: 'General Fitness',
    description: 'Improve overall fitness, health, and physical capacity.',
  ),
  hybrid(
    apiValue: 'hybrid',
    label: 'Hybrid',
    description:
        'Combine resistance training with other sports or conditioning.',
  );

  const TrainingGoal({
    required this.apiValue,
    required this.label,
    required this.description,
  });

  final String apiValue;
  final String label;
  final String description;

  static TrainingGoal fromApiValue(String value) {
    return TrainingGoal.values.firstWhere(
      (goal) => goal.apiValue == value,
      orElse: () => throw FormatException('Unknown training goal: $value'),
    );
  }
}

class GoalData {
  const GoalData({
    required this.id,
    required this.userId,
    required this.primaryGoal,
    required this.secondaryGoals,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final TrainingGoal primaryGoal;
  final List<TrainingGoal> secondaryGoals;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GoalData.fromJson(Map<String, dynamic> json) {
    final secondaryGoalsJson = json['secondary_goals'];

    return GoalData(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      primaryGoal: TrainingGoal.fromApiValue(json['primary_goal'] as String),
      secondaryGoals: secondaryGoalsJson is List
          ? secondaryGoalsJson
                .map((goal) => TrainingGoal.fromApiValue(goal as String))
                .toList(growable: false)
          : const <TrainingGoal>[],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class TrainingPreferencesData {
  const TrainingPreferencesData({
    required this.id,
    required this.userId,
    required this.daysPerWeek,
    required this.sessionDurationMinutes,
    required this.availableDays,
    required this.noDedicatedLegDay,
    required this.armSpecialization,
    required this.sportsConfigured,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final int daysPerWeek;
  final int sessionDurationMinutes;
  final List<int> availableDays;
  final bool noDedicatedLegDay;
  final bool armSpecialization;
  final bool sportsConfigured;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TrainingPreferencesData.fromJson(
    Map<String, dynamic> json,
  ) {
    return TrainingPreferencesData(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      daysPerWeek: json['days_per_week'] as int,
      sessionDurationMinutes:
          json['session_duration_minutes'] as int,
      availableDays: (json['available_days'] as List<dynamic>)
          .map((day) => day as int)
          .toList(growable: false),
      noDedicatedLegDay:
          json['no_dedicated_leg_day'] as bool,
      armSpecialization:
          json['arm_specialization'] as bool,
      sportsConfigured:
          json['sports_configured'] as bool,
      createdAt: DateTime.parse(
        json['created_at'] as String,
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] as String,
      ),
    );
  }
}

class OnboardingData {
  const OnboardingData({required this.goal, required this.trainingPreferences});

  final GoalData? goal;
  final TrainingPreferencesData? trainingPreferences;

  bool get hasGoal => goal != null;

  bool get hasTrainingPreferences => trainingPreferences != null;

  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    final goalJson = json['goal'];
    final preferencesJson = json['training_preferences'];

    return OnboardingData(
      goal: goalJson is Map
          ? GoalData.fromJson(Map<String, dynamic>.from(goalJson))
          : null,
      trainingPreferences: preferencesJson is Map
          ? TrainingPreferencesData.fromJson(
              Map<String, dynamic>.from(preferencesJson),
            )
          : null,
    );
  }
}
