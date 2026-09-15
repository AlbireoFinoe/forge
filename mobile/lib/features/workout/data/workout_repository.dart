import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'workout_models.dart';

class WorkoutException implements Exception {
  const WorkoutException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class WorkoutRepository {
  WorkoutRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<WorkoutSessionData?> getCurrentWorkout() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/workouts/current');

      return WorkoutSessionData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }

      throw _toWorkoutException(error);
    }
  }

  Future<WorkoutSessionData> startWorkout(String programDayId) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/workouts/start',
        data: {'program_day_id': programDayId},
      );

      return WorkoutSessionData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toWorkoutException(error);
    }
  }

  Future<WorkoutSetData> logSet({
    required String workoutSetId,
    required int actualReps,
    double? weightKg,
    double? rpe,
  }) async {
    try {
      final response = await _apiClient.dio.patch<dynamic>(
        '/workouts/sets/$workoutSetId',
        data: {'actual_reps': actualReps, 'weight_kg': weightKg, 'rpe': rpe},
      );

      return WorkoutSetData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toWorkoutException(error);
    }
  }

  Future<WorkoutExerciseData> skipExercise(String workoutExerciseId) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/workouts/exercises/'
        '$workoutExerciseId/skip',
      );

      return WorkoutExerciseData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toWorkoutException(error);
    }
  }

  Future<WorkoutSessionData> finishWorkout(String workoutId) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/workouts/$workoutId/finish',
      );

      return WorkoutSessionData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toWorkoutException(error);
    }
  }

  Future<WorkoutSessionData> getWorkoutById(String workoutId) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/workouts/$workoutId',
      );

      return WorkoutSessionData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toWorkoutException(error);
    }
  }

  Future<List<WorkoutSummaryData>> getHistory() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/workouts/history');

      final value = response.data;

      if (value is! List) {
        throw const WorkoutException('Unexpected response from FORGE server.');
      }

      return value
          .map((item) => WorkoutSummaryData.fromJson(_asJsonObject(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _toWorkoutException(error);
    }
  }

  Map<String, dynamic> _asJsonObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const WorkoutException('Unexpected response from FORGE server.');
  }

  WorkoutException _toWorkoutException(DioException error) {
    return WorkoutException(
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
        final first = detail.first;

        if (first is Map) {
          final message = first['msg'];

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
