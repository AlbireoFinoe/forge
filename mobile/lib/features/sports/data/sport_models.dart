enum SportIntensity {
  low(apiValue: 'low', label: 'Low'),
  moderate(apiValue: 'moderate', label: 'Moderate'),
  high(apiValue: 'high', label: 'High');

  const SportIntensity({required this.apiValue, required this.label});

  final String apiValue;
  final String label;

  static SportIntensity fromApiValue(String value) {
    return SportIntensity.values.firstWhere(
      (intensity) => intensity.apiValue == value,
      orElse: () => throw FormatException('Unknown sport intensity: $value'),
    );
  }
}

class SportActivityData {
  const SportActivityData({
    required this.id,
    required this.userId,
    required this.sportType,
    required this.dayOfWeek,
    required this.durationMinutes,
    required this.intensity,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String sportType;
  final int dayOfWeek;
  final int durationMinutes;
  final SportIntensity intensity;
  final DateTime createdAt;

  String get displayName {
    final words = sportType.trim().split(RegExp(r'\s+'));

    return words
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  factory SportActivityData.fromJson(Map<String, dynamic> json) {
    return SportActivityData(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sportType: json['sport_type'] as String,
      dayOfWeek: json['day_of_week'] as int,
      durationMinutes: json['duration_minutes'] as int,
      intensity: SportIntensity.fromApiValue(json['intensity'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
