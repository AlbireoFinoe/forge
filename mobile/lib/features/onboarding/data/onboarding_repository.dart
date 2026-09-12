import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'onboarding_models.dart';

class OnboardingException implements Exception {
  const OnboardingException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class OnboardingRepository {
  OnboardingRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<OnboardingData> getOnboarding() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/onboarding');

      return OnboardingData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toOnboardingException(error);
    }
  }

  Future<GoalData> updateGoal({
    required TrainingGoal primaryGoal,
    required List<TrainingGoal> secondaryGoals,
  }) async {
    try {
      final response = await _apiClient.dio.put<dynamic>(
        '/onboarding/goal',
        data: {
          'primary_goal': primaryGoal.apiValue,
          'secondary_goals': secondaryGoals
              .map((goal) => goal.apiValue)
              .toList(growable: false),
        },
      );

      return GoalData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toOnboardingException(error);
    }
  }

  Future<TrainingPreferencesData> updateTrainingPreferences({
    required int daysPerWeek,
    required int sessionDurationMinutes,
    required List<int> availableDays,
    required bool noDedicatedLegDay,
    required bool armSpecialization,
  }) async {
    try {
      final response = await _apiClient.dio.put<dynamic>(
        '/onboarding/training-preferences',
        data: {
          'days_per_week': daysPerWeek,
          'session_duration_minutes': sessionDurationMinutes,
          'available_days': availableDays,
          'no_dedicated_leg_day': noDedicatedLegDay,
          'arm_specialization': armSpecialization,
        },
      );

      return TrainingPreferencesData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toOnboardingException(error);
    }
  }

  Map<String, dynamic> _asJsonObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const OnboardingException('Unexpected response from FORGE server.');
  }

  OnboardingException _toOnboardingException(DioException error) {
    return OnboardingException(
      _extractErrorMessage(error),
      statusCode: error.response?.statusCode,
    );
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;

    if (data is Map) {
      final detail = data['detail'];

      if (detail is String && detail.isNotEmpty) {
        return detail;
      }

      if (detail is List && detail.isNotEmpty) {
        final firstError = detail.first;

        if (firstError is Map) {
          final message = firstError['msg'];

          if (message is String && message.isNotEmpty) {
            return message;
          }
        }
      }
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Could not connect to FORGE server.';
    }

    if (error.type == DioExceptionType.connectionTimeout) {
      return 'Connection to FORGE server timed out.';
    }

    return 'Something went wrong while communicating with FORGE.';
  }
}
