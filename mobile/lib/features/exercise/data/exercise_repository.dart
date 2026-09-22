import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'exercise_models.dart';
import 'exercise_summary_data.dart';

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

  Future<List<ExerciseSummaryData>> getExercises({
    String? muscle,
    String? search,
  }) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/exercises',
        queryParameters: {
          if (muscle != null && muscle.trim().isNotEmpty)
            'muscle': muscle.trim().toUpperCase(),
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );

      return _asJsonList(response.data)
          .map(ExerciseSummaryData.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw _toExerciseException(error);
    }
  }

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

  List<Map<String, dynamic>> _asJsonList(dynamic value) {
    if (value is! List) {
      throw const ExerciseException('Unexpected response from FORGE server.');
    }

    return value
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          }

          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }

          throw const ExerciseException(
            'Unexpected response from FORGE server.',
          );
        })
        .toList(growable: false);
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

    return 'Could not load exercise data.';
  }
}
