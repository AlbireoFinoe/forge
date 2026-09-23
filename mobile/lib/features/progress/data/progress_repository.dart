import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'progress_models.dart';

class ProgressException implements Exception {
  const ProgressException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ProgressRepository {
  ProgressRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ProgressOverviewData> getOverview() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/progress/overview');

      return ProgressOverviewData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toProgressException(error);
    }
  }

  Map<String, dynamic> _asJsonObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const ProgressException('Unexpected response from FORGE server.');
  }

  ProgressException _toProgressException(DioException error) {
    return ProgressException(
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

    return 'Could not load training progress.';
  }
}
