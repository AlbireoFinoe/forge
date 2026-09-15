enum TrainingExperience {
  beginner(
    apiValue: 'beginner',
    label: 'Beginner',
    description:
        'New to structured strength training or still building consistency.',
  ),
  intermediate(
    apiValue: 'intermediate',
    label: 'Intermediate',
    description: 'Training consistently and familiar with common exercises and programming.',
  ),
  advanced(
    apiValue: 'advanced',
    label: 'Advanced',
    description: 'Several years of structured training with strong technical experience.',
  );

  const TrainingExperience({
    required this.apiValue,
    required this.label,
    required this.description,
  });

  final String apiValue;
  final String label;
  final String description;

  static TrainingExperience? fromApiValue(String? value) {
    if (value == null) {
      return null;
    }

    for (final experience in TrainingExperience.values) {
      if (experience.apiValue == value) {
        return experience;
      }
    }

    throw FormatException('Unknown training experience: $value');
  }
}

class ProfileData {
  const ProfileData({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.birthDate,
    required this.gender,
    required this.heightCm,
    required this.currentWeightKg,
    required this.unitSystem,
    required this.experienceLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;

  final String? displayName;
  final DateTime? birthDate;
  final String? gender;

  final double? heightCm;
  final double? currentWeightKg;

  final String unitSystem;
  final TrainingExperience? experienceLevel;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasExperienceLevel => experienceLevel != null;

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      birthDate: json['birth_date'] == null
          ? null
          : DateTime.parse(json['birth_date'] as String),
      gender: json['gender'] as String?,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      currentWeightKg: (json['current_weight_kg'] as num?)?.toDouble(),
      unitSystem: json['unit_system'] as String,
      experienceLevel: TrainingExperience.fromApiValue(
        json['experience_level'] as String?,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
