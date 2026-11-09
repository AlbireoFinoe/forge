import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/api/api_client.dart';
import 'package:forge/core/storage/secure_token_storage.dart';

typedef _RequestHandler = Future<ResponseBody> Function(RequestOptions options);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handleRequest);

  final _RequestHandler _handleRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handleRequest(options);
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStorage extends SecureTokenStorage {
  _MemoryTokenStorage({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;
  int deleteCount = 0;
  int saveCount = 0;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    saveCount++;
  }

  @override
  Future<void> deleteTokens() async {
    accessToken = null;
    refreshToken = null;
    deleteCount++;
  }
}

ResponseBody _jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

DioException _connectionFailure(RequestOptions options) {
  return DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
  );
}

Dio _dioWithAdapter(HttpClientAdapter adapter) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://forge-test.invalid/api/v1',
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  )..httpClientAdapter = adapter;
}

void main() {
  group('ApiClient authentication regression', () {
    test('sends a bearer token on protected requests', () async {
      final storage = _MemoryTokenStorage(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
      );
      String? authorization;
      final client = ApiClient(
        tokenStorage: storage,
        onUnauthorized: () {},
        dio: _dioWithAdapter(
          _FakeAdapter((options) async {
            authorization = options.headers['Authorization'] as String?;
            return _jsonResponse(200, {'ok': true});
          }),
        ),
      );

      await client.dio.get<dynamic>('/protected');

      expect(authorization, 'Bearer test-access-token');
    });

    test(
      'does not send an Authorization header without an access token',
      () async {
        final storage = _MemoryTokenStorage(refreshToken: 'test-refresh-token');
        late RequestOptions request;
        final client = ApiClient(
          tokenStorage: storage,
          onUnauthorized: () {},
          dio: _dioWithAdapter(
            _FakeAdapter((options) async {
              request = options;
              return _jsonResponse(200, {'ok': true});
            }),
          ),
        );

        await client.dio.get<dynamic>('/public');

        expect(request.headers.containsKey('Authorization'), isFalse);
      },
    );

    test(
      'a protected 401 requests a refresh and retries the request',
      () async {
        final storage = _MemoryTokenStorage(
          accessToken: 'old-access-token',
          refreshToken: 'old-refresh-token',
        );
        final authorizationHeaders = <String?>[];
        final refreshPaths = <String>[];
        final refreshBodies = <Object?>[];
        final client = ApiClient(
          tokenStorage: storage,
          onUnauthorized: () {},
          dio: _dioWithAdapter(
            _FakeAdapter((options) async {
              authorizationHeaders
                  .add(options.headers['Authorization'] as String?);
              if (authorizationHeaders.length == 1) {
                return _jsonResponse(401, {'detail': 'expired'});
              }
              return _jsonResponse(200, {'ok': true});
            }),
          ),
          refreshDio: _dioWithAdapter(
            _FakeAdapter((options) async {
              refreshPaths.add(options.path);
              refreshBodies.add(options.data);
              return _jsonResponse(200, {
                'access_token': 'new-access-token',
                'refresh_token': 'new-refresh-token',
              });
            }),
          ),
        );

        final response = await client.dio.get<dynamic>('/protected');

        expect(response.statusCode, 200);
        expect(authorizationHeaders, [
          'Bearer old-access-token',
          'Bearer new-access-token',
        ]);
        expect(refreshPaths, ['/auth/refresh']);
        expect(refreshBodies, [
          {'refresh_token': 'old-refresh-token'},
        ]);
      },
    );

    test(
      'saves refreshed tokens and retries with the new access token',
      () async {
        final storage = _MemoryTokenStorage(
          accessToken: 'old-access-token',
          refreshToken: 'old-refresh-token',
        );
        final authorizationHeaders = <String?>[];
        final client = ApiClient(
          tokenStorage: storage,
          onUnauthorized: () {},
          dio: _dioWithAdapter(
            _FakeAdapter((options) async {
              authorizationHeaders.add(
                options.headers['Authorization'] as String?,
              );
              if (authorizationHeaders.length == 1) {
                return _jsonResponse(401, {'detail': 'expired'});
              }
              return _jsonResponse(200, {'ok': true});
            }),
          ),
          refreshDio: _dioWithAdapter(
            _FakeAdapter((_) async {
              return _jsonResponse(200, {
                'access_token': 'rotated-access-token',
                'refresh_token': 'rotated-refresh-token',
              });
            }),
          ),
        );

        await client.dio.get<dynamic>('/protected');

        expect(storage.saveCount, 1);
        expect(storage.accessToken, 'rotated-access-token');
        expect(storage.refreshToken, 'rotated-refresh-token');
        expect(authorizationHeaders, [
          'Bearer old-access-token',
          'Bearer rotated-access-token',
        ]);
      },
    );

    test(
      'invalid refresh clears tokens and notifies unauthorized once',
      () async {
        final storage = _MemoryTokenStorage(
          accessToken: 'expired-access-token',
          refreshToken: 'invalid-refresh-token',
        );
        var unauthorizedCount = 0;
        final client = ApiClient(
          tokenStorage: storage,
          onUnauthorized: () => unauthorizedCount++,
          dio: _dioWithAdapter(
            _FakeAdapter((options) async {
              return _jsonResponse(401, {'detail': 'expired'});
            }),
          ),
          refreshDio: _dioWithAdapter(
            _FakeAdapter((options) async {
              return _jsonResponse(401, {'detail': 'invalid refresh'});
            }),
          ),
        );

        await expectLater(
          client.dio.get<dynamic>('/protected'),
          throwsA(isA<DioException>()),
        );

        expect(storage.accessToken, isNull);
        expect(storage.refreshToken, isNull);
        expect(storage.deleteCount, 1);
        expect(unauthorizedCount, 1);
      },
    );

    test(
      'temporary refresh network failure preserves the current session',
      () async {
        final storage = _MemoryTokenStorage(
          accessToken: 'current-access-token',
          refreshToken: 'current-refresh-token',
        );
        var unauthorizedCount = 0;
        var refreshCount = 0;
        final client = ApiClient(
          tokenStorage: storage,
          onUnauthorized: () => unauthorizedCount++,
          dio: _dioWithAdapter(
            _FakeAdapter((options) async {
              return _jsonResponse(401, {'detail': 'expired'});
            }),
          ),
          refreshDio: _dioWithAdapter(
            _FakeAdapter((options) async {
              refreshCount++;
              throw _connectionFailure(options);
            }),
          ),
        );

        await expectLater(
          client.dio.get<dynamic>('/protected'),
          throwsA(
            isA<DioException>().having(
              (error) => error.type,
              'type',
              DioExceptionType.connectionError,
            ),
          ),
        );

        expect(refreshCount, 1);
        expect(storage.accessToken, 'current-access-token');
        expect(storage.refreshToken, 'current-refresh-token');
        expect(storage.deleteCount, 0);
        expect(unauthorizedCount, 0);
      },
    );

    test('a second 401 expires the session without another refresh', () async {
      final storage = _MemoryTokenStorage(
        accessToken: 'expired-access-token',
        refreshToken: 'valid-refresh-token',
      );
      var protectedCount = 0;
      var refreshCount = 0;
      var unauthorizedCount = 0;
      final client = ApiClient(
        tokenStorage: storage,
        onUnauthorized: () => unauthorizedCount++,
        dio: _dioWithAdapter(
          _FakeAdapter((options) async {
            protectedCount++;
            return _jsonResponse(401, {'detail': 'still unauthorized'});
          }),
        ),
        refreshDio: _dioWithAdapter(
          _FakeAdapter((_) async {
            refreshCount++;
            return _jsonResponse(200, {
              'access_token': 'new-access-token',
              'refresh_token': 'new-refresh-token',
            });
          }),
        ),
      );

      await expectLater(
        client.dio.get<dynamic>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(protectedCount, 2);
      expect(refreshCount, 1);
      expect(storage.deleteCount, 1);
      expect(unauthorizedCount, 1);
    });

    test(
      'concurrent 401 responses share one refresh and retry with its token',
      () async {
        final storage = _MemoryTokenStorage(
          accessToken: 'old-access-token',
          refreshToken: 'old-refresh-token',
        );
        final bothRequestsArrived = Completer<void>();
        final releaseInitialResponses = Completer<void>();
        final releaseRefreshResponse = Completer<void>();
        final refreshStarted = Completer<void>();
        var initialRequestCount = 0;
        var refreshCount = 0;
        final retryHeaders = <String?>[];

        final protectedAdapter = _FakeAdapter((options) async {
          if (options.extra['forge_auth_retry'] == true) {
            retryHeaders.add(options.headers['Authorization'] as String?);
            return _jsonResponse(200, {'ok': true});
          }

          initialRequestCount++;
          if (initialRequestCount == 2) {
            bothRequestsArrived.complete();
          }
          await releaseInitialResponses.future;
          return _jsonResponse(401, {'detail': 'expired'});
        });

        final refreshAdapter = _FakeAdapter((_) async {
          refreshCount++;
          if (!refreshStarted.isCompleted) {
            refreshStarted.complete();
          }
          await releaseRefreshResponse.future;
          return _jsonResponse(200, {
            'access_token': 'shared-new-access-token',
            'refresh_token': 'shared-new-refresh-token',
          });
        });

        final client = ApiClient(
          tokenStorage: storage,
          onUnauthorized: () {},
          dio: _dioWithAdapter(protectedAdapter),
          refreshDio: _dioWithAdapter(refreshAdapter),
        );

        final firstRequest = client.dio.get<dynamic>('/protected/one');
        final secondRequest = client.dio.get<dynamic>('/protected/two');
        await bothRequestsArrived.future;
        releaseInitialResponses.complete();
        await refreshStarted.future;
        await Future<void>.delayed(Duration.zero);
        releaseRefreshResponse.complete();
        final responses = await Future.wait([firstRequest, secondRequest]);

        expect(responses, hasLength(2));
        expect(refreshCount, 1);
        expect(storage.saveCount, 1);
        expect(retryHeaders, [
          'Bearer shared-new-access-token',
          'Bearer shared-new-access-token',
        ]);
      },
    );

    test(
      'login, register, and refresh 401s do not start refresh loops',
      () async {
        final storage = _MemoryTokenStorage(
          accessToken: 'test-access-token',
          refreshToken: 'test-refresh-token',
        );
        var refreshCount = 0;
        var unauthorizedCount = 0;
        final client = ApiClient(
          tokenStorage: storage,
          onUnauthorized: () => unauthorizedCount++,
          dio: _dioWithAdapter(
            _FakeAdapter((_) async {
              return _jsonResponse(401, {'detail': 'unauthorized'});
            }),
          ),
          refreshDio: _dioWithAdapter(
            _FakeAdapter((_) async {
              refreshCount++;
              return _jsonResponse(200, {
                'access_token': 'unexpected-access-token',
                'refresh_token': 'unexpected-refresh-token',
              });
            }),
          ),
        );

        for (final path in ['/auth/login', '/auth/register', '/auth/refresh']) {
          await expectLater(
            client.dio.post<dynamic>(path, data: const {}),
            throwsA(isA<DioException>()),
          );
        }

        expect(refreshCount, 0);
        expect(unauthorizedCount, 0);
        expect(storage.deleteCount, 0);
      },
    );

    test(
      'does not print tokens or credentials during authentication requests',
      () async {
        const accessToken = 'synthetic-access-secret';
        const email = 'synthetic@example.invalid';
        const password = 'synthetic-password';
        final storage = _MemoryTokenStorage(
          accessToken: accessToken,
          refreshToken: 'synthetic-refresh-secret',
        );
        final output = <String>[];
        final client = ApiClient(
          tokenStorage: storage,
          onUnauthorized: () {},
          dio: _dioWithAdapter(
            _FakeAdapter((_) async => _jsonResponse(200, {'ok': true})),
          ),
          refreshDio: _dioWithAdapter(
            _FakeAdapter((_) async => _jsonResponse(200, {'ok': true})),
          ),
        );

        await runZoned(
          () => client.dio.post<dynamic>(
            '/auth/login',
            data: const {'email': email, 'password': password},
          ),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => output.add(line),
          ),
        );

        expect(output.join('\n'), isNot(contains(accessToken)));
        expect(
          output.join('\n'),
          isNot(contains('synthetic-refresh-secret')),
        );
        expect(output.join('\n'), isNot(contains(password)));
        expect(output.join('\n'), isNot(contains(email)));
      },
    );
  });
}
