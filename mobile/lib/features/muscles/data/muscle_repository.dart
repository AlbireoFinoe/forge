import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'muscle_models.dart';

class MuscleException implements Exception {
  const MuscleException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class MuscleRepository {
  MuscleRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MuscleGroupData>> getMuscleGroups() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/muscles');

      return _asJsonList(response.data)
          .map((item) => MuscleGroupData.fromJson(_asJsonObject(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _toMuscleException(error);
    }
  }

  Future<List<MusclePriorityData>> getPriorities() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/muscles/priorities');

      return _asJsonList(response.data)
          .map((item) => MusclePriorityData.fromJson(_asJsonObject(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _toMuscleException(error);
    }
  }

  Future<List<MusclePriorityData>> updatePriorities(
    Map<String, MusclePriorityLevel> priorities,
  ) async {
    try {
      final entries = priorities.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key));

      final response = await _apiClient.dio.put<dynamic>(
        '/muscles/priorities',
        data: {
          'priorities': [
            for (final entry in entries)
              {'muscle_code': entry.key, 'priority': entry.value.apiValue},
          ],
        },
      );

      return _asJsonList(response.data)
          .map((item) => MusclePriorityData.fromJson(_asJsonObject(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _toMuscleException(error);
    }
  }

  List<dynamic> _asJsonList(dynamic value) {
    if (value is List) {
      return value;
    }

    throw const MuscleException('Unexpected response from FORGE server.');
  }

  Map<String, dynamic> _asJsonObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const MuscleException('Unexpected response from FORGE server.');
  }

  MuscleException _toMuscleException(DioException error) {
    return MuscleException(
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
