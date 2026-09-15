import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'sport_models.dart';

class SportException implements Exception {
  const SportException(
    this.message, {
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class SportRepository {
  SportRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<SportActivityData>> getSports() async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/sports',
      );

      return _parseSportList(response.data);
    } on DioException catch (error) {
      throw _toSportException(error);
    }
  }

  Future<SportActivityData> createSport({
    required String sportType,
    required int dayOfWeek,
    required int durationMinutes,
    required SportIntensity intensity,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/sports',
        data: {
          'sport_type': sportType.trim(),
          'day_of_week': dayOfWeek,
          'duration_minutes': durationMinutes,
          'intensity': intensity.apiValue,
        },
      );

      return SportActivityData.fromJson(
        _asJsonObject(response.data),
      );
    } on DioException catch (error) {
      throw _toSportException(error);
    }
  }

  Future<SportActivityData> updateSport({
    required String sportId,
    required String sportType,
    required int dayOfWeek,
    required int durationMinutes,
    required SportIntensity intensity,
  }) async {
    try {
      final response = await _apiClient.dio.patch<dynamic>(
        '/sports/$sportId',
        data: {
          'sport_type': sportType.trim(),
          'day_of_week': dayOfWeek,
          'duration_minutes': durationMinutes,
          'intensity': intensity.apiValue,
        },
      );

      return SportActivityData.fromJson(
        _asJsonObject(response.data),
      );
    } on DioException catch (error) {
      throw _toSportException(error);
    }
  }

  Future<void> deleteSport(
    String sportId,
  ) async {
    try {
      await _apiClient.dio.delete<dynamic>(
        '/sports/$sportId',
      );
    } on DioException catch (error) {
      throw _toSportException(error);
    }
  }

  Future<void> setConfigured(
    bool configured,
  ) async {
    try {
      final response = await _apiClient.dio.put<dynamic>(
        '/sports/setup',
        data: {
          'configured': configured,
        },
      );

      final data = _asJsonObject(response.data);

      if (data['configured'] != configured) {
        throw const SportException(
          'Unexpected sports setup response from FORGE server.',
        );
      }
    } on DioException catch (error) {
      throw _toSportException(error);
    }
  }

  List<SportActivityData> _parseSportList(
    dynamic value,
  ) {
    if (value is! List) {
      throw const SportException(
        'Unexpected response from FORGE server.',
      );
    }

    return value
        .map(
          (item) => SportActivityData.fromJson(
            _asJsonObject(item),
          ),
        )
        .toList(growable: false);
  }

  Map<String, dynamic> _asJsonObject(
    dynamic value,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const SportException(
      'Unexpected response from FORGE server.',
    );
  }

  SportException _toSportException(
    DioException error,
  ) {
    return SportException(
      _extractErrorMessage(error),
      statusCode: error.response?.statusCode,
    );
  }

  String _extractErrorMessage(
    DioException error,
  ) {
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

          if (message is String &&
              message.isNotEmpty) {
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