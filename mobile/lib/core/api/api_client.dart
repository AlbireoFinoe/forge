import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/secure_token_storage.dart';

typedef UnauthorizedHandler = void Function();

class ApiClient {
  ApiClient({
    required SecureTokenStorage tokenStorage,
    required UnauthorizedHandler onUnauthorized,
    Dio? dio,
  }) : _tokenStorage = tokenStorage,
       _onUnauthorized = onUnauthorized,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: ApiConfig.baseUrl,
               connectTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 30),
               receiveTimeout: const Duration(seconds: 30),
               headers: const {
                 'Accept': 'application/json',
                 'Content-Type': 'application/json',
               },
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readAccessToken();

          if (token != null && token.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final path = error.requestOptions.path;

          if (statusCode == 401 && !_isAuthenticationRequest(path)) {
            await _tokenStorage.deleteAccessToken();

            _onUnauthorized();
          }

          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureTokenStorage _tokenStorage;
  final UnauthorizedHandler _onUnauthorized;

  bool _isAuthenticationRequest(String path) {
    return path == '/auth/login' || path == '/auth/register';
  }

  Dio get dio => _dio;
}
