import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/secure_token_storage.dart';

typedef UnauthorizedHandler = void Function();

enum _RefreshStatus { success, invalidSession, temporaryFailure }

class _RefreshResult {
  const _RefreshResult(this.status, {this.error});

  final _RefreshStatus status;
  final DioException? error;
}

class ApiClient {
  ApiClient({
    required SecureTokenStorage tokenStorage,
    required UnauthorizedHandler onUnauthorized,
    Dio? dio,
    Dio? refreshDio,
  }) : _tokenStorage = tokenStorage,
       _onUnauthorized = onUnauthorized,
       _dio = dio ?? Dio(_baseOptions()),
       _refreshDio = refreshDio ?? Dio(_baseOptions()) {
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

          if (statusCode != 401 || _isAuthenticationRequest(path)) {
            handler.next(error);
            return;
          }

          final alreadyRetried =
              error.requestOptions.extra[_retryMarkerKey] == true;

          if (alreadyRetried) {
            await _expireSession();
            handler.next(error);
            return;
          }

          final refreshResult = await _refreshSession();

          switch (refreshResult.status) {
            case _RefreshStatus.success:
              try {
                final response = await _retryRequest(error.requestOptions);

                handler.resolve(response);
              } on DioException catch (retryError) {
                handler.next(retryError);
              }

              return;

            case _RefreshStatus.invalidSession:
              await _expireSession();
              handler.next(error);
              return;

            case _RefreshStatus.temporaryFailure:
              handler.next(refreshResult.error ?? error);
              return;
          }
        },
      ),
    );
  }

  static const String _retryMarkerKey = 'forge_auth_retry';

  final Dio _dio;
  final Dio _refreshDio;

  final SecureTokenStorage _tokenStorage;
  final UnauthorizedHandler _onUnauthorized;

  Future<_RefreshResult>? _refreshFuture;

  static BaseOptions _baseOptions() {
    return BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
  }

  bool _isAuthenticationRequest(String path) {
    return path == '/auth/login' ||
        path == '/auth/register' ||
        path == '/auth/refresh';
  }

  Future<_RefreshResult> _refreshSession() async {
    final existing = _refreshFuture;

    if (existing != null) {
      return existing;
    }

    final future = _performRefresh();

    _refreshFuture = future;

    try {
      return await future;
    } finally {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    }
  }

  Future<_RefreshResult> _performRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();

    if (refreshToken == null || refreshToken.trim().isEmpty) {
      return const _RefreshResult(_RefreshStatus.invalidSession);
    }

    try {
      final response = await _refreshDio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data;

      if (data is! Map) {
        return const _RefreshResult(_RefreshStatus.invalidSession);
      }

      final accessToken = data['access_token'];

      final newRefreshToken = data['refresh_token'];

      if (accessToken is! String ||
          accessToken.trim().isEmpty ||
          newRefreshToken is! String ||
          newRefreshToken.trim().isEmpty) {
        return const _RefreshResult(_RefreshStatus.invalidSession);
      }

      await _tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );

      return const _RefreshResult(_RefreshStatus.success);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;

      if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
        return const _RefreshResult(_RefreshStatus.invalidSession);
      }

      return _RefreshResult(_RefreshStatus.temporaryFailure, error: error);
    }
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions request) async {
    final accessToken = await _tokenStorage.readAccessToken();

    if (accessToken == null || accessToken.trim().isEmpty) {
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.unknown,
        error: 'Access token unavailable after refresh.',
      );
    }

    final headers = Map<String, dynamic>.from(request.headers);

    headers['Authorization'] = 'Bearer $accessToken';

    final extra = Map<String, dynamic>.from(request.extra);

    extra[_retryMarkerKey] = true;

    return _dio.request<dynamic>(
      request.path,
      data: request.data,
      queryParameters: request.queryParameters,
      cancelToken: request.cancelToken,
      onSendProgress: request.onSendProgress,
      onReceiveProgress: request.onReceiveProgress,
      options: Options(
        method: request.method,
        headers: headers,
        responseType: request.responseType,
        contentType: request.contentType,
        validateStatus: request.validateStatus,
        sendTimeout: request.sendTimeout,
        receiveTimeout: request.receiveTimeout,
        extra: extra,
      ),
    );
  }

  Future<void> _expireSession() async {
    await _tokenStorage.deleteTokens();
    _onUnauthorized();
  }

  Dio get dio => _dio;
}
