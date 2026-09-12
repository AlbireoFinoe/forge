import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_token_storage.dart';
import 'auth_user.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required SecureTokenStorage tokenStorage,
  }) : _apiClient = apiClient,
       _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final SecureTokenStorage _tokenStorage;

  Future<AuthUser> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/auth/register',
        data: {'email': email, 'password': password},
      );

      return AuthUser.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toAuthException(error);
    }
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = _asJsonObject(response.data);

      final token = data['access_token'];

      if (token is! String || token.trim().isEmpty) {
        throw const AuthException(
          'Login response did not contain an access token.',
        );
      }

      await _tokenStorage.saveAccessToken(token);

      try {
        return await getCurrentUser();
      } on AuthException catch (error) {
        if (error.isUnauthorized) {
          await _tokenStorage.deleteAccessToken();
        }

        rethrow;
      }
    } on DioException catch (error) {
      throw _toAuthException(error);
    }
  }

  Future<AuthUser> getCurrentUser() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/users/me');

      return AuthUser.fromJson(_asJsonObject(response.data));
    } on DioException catch (error) {
      throw _toAuthException(error);
    }
  }

  Future<bool> hasStoredToken() {
    return _tokenStorage.hasAccessToken();
  }

  Future<void> logout() {
    return _tokenStorage.deleteAccessToken();
  }

  Map<String, dynamic> _asJsonObject(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw const AuthException('Unexpected response from server.');
  }

  AuthException _toAuthException(DioException error) {
    return AuthException(
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

    return 'Something went wrong while communicating with FORGE.';
  }
}
