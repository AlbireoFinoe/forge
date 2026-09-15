import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'profile_models.dart';

class ProfileException implements Exception {
  const ProfileException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ProfileRepository {
  ProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ProfileData> getProfile() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/profile');

      return ProfileData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toProfileException(error);
    }
  }

  Future<ProfileData> updateExperienceLevel(
    TrainingExperience experience,
  ) async {
    try {
      final response = await _apiClient.dio.patch<dynamic>(
        '/profile',
        data: {'experience_level': experience.apiValue},
      );

      return ProfileData.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toProfileException(error);
    }
  }

  Map<String, dynamic> _asJsonObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const ProfileException('Unexpected response from FORGE server.');
  }

  ProfileException _toProfileException(DioException error) {
    return ProfileException(
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
