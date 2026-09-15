import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'program_models.dart';

class ProgramException implements Exception {
  const ProgramException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ProgramRepository {
  ProgramRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ProgramDetailData?> getCurrentProgram() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/programs/current');

      return ProgramDetailData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }

      throw _toProgramException(error);
    }
  }

  Future<ProgramGenerateData> generateProgram() async {
    try {
      final response = await _apiClient.dio.post<dynamic>('/programs/generate');

      return ProgramGenerateData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toProgramException(error);
    }
  }

  Future<List<ProgramSummaryData>> getProgramHistory() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/programs/history');

      final data = response.data;

      if (data is! List) {
        throw const ProgramException('Unexpected response from FORGE server.');
      }

      return data
          .map((item) => ProgramSummaryData.fromJson(_asJsonObject(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _toProgramException(error);
    }
  }

  Future<ProgramDetailData> getProgramById(String programId) async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/programs/$programId',
      );

      return ProgramDetailData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toProgramException(error);
    }
  }

  Map<String, dynamic> _asJsonObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const ProgramException('Unexpected response from FORGE server.');
  }

  ProgramException _toProgramException(DioException error) {
    return ProgramException(
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
