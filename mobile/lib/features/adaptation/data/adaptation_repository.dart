import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'adaptation_models.dart';

class AdaptationException implements Exception {
  const AdaptationException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AdaptationRepository {
  AdaptationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AdaptationOverviewData> getOverview() async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/adaptation/overview',
      );

      return AdaptationOverviewData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toAdaptationException(error);
    }
  }

  Future<AdaptationRecommendationData> getExerciseRecommendation(
    String exerciseCode,
  ) async {
    try {
      final code = Uri.encodeComponent(exerciseCode);

      final response = await _apiClient.dio.get<dynamic>(
        '/adaptation/exercises/$code',
      );

      return AdaptationRecommendationData.fromJson(
        _asJsonObject(response.data),
      );
    } on DioException catch (error) {
      throw _toAdaptationException(error);
    }
  }

  Map<String, dynamic> _asJsonObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const AdaptationException('Unexpected response from FORGE server.');
  }

  AdaptationException _toAdaptationException(DioException error) {
    return AdaptationException(
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
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Could not connect to FORGE server.';
    }

    if (error.type == DioExceptionType.connectionTimeout) {
      return 'Connection to FORGE server timed out.';
    }

    return 'Could not load training adaptation.';
  }
}
