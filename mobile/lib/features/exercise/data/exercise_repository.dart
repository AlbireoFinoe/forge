import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'exercise_models.dart';

class ExerciseException implements Exception {
  const ExerciseException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ExerciseRepository {
  ExerciseRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ExerciseDetailData> getExerciseById(String exerciseId) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/exercises/$exerciseId',
      );

      return ExerciseDetailData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toExerciseException(error);
    }
  }

  Map<String, dynamic> _asJsonObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const ExerciseException('Unexpected response from FORGE server.');
  }

  ExerciseException _toExerciseException(DioException error) {
    return ExerciseException(
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

    return 'Could not load exercise details.';
  }
}
