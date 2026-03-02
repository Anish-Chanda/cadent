import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/services/auth_service.dart';
import 'package:cadence/services/http_client.dart';

// Dio interceptor to return predefined responses by method + path.
class MockingInterceptor extends Interceptor {
  final Map<String, _MockReply> replies = {};

  void reply(String method, String path, {
    required int statusCode,
    dynamic data,
    String? statusMessage,
  }) {
    final key = '${method.toUpperCase()} $path';
    replies[key] = _MockReply(statusCode: statusCode, data: data, statusMessage: statusMessage);
  }

  void throwError(String method, String path, DioException error) {
    final key = '${method.toUpperCase()} $path';
    replies[key] = _MockReply.throwing(error);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = '${options.method.toUpperCase()} ${options.path}';
    final mock = replies[key];
    if (mock == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: 'No mock registered for $key',
        ),
      );
      return;
    }

    if (mock.error != null) {
      handler.reject(mock.error!);
      return;
    }

    handler.resolve(
      Response(
        requestOptions: options,
        statusCode: mock.statusCode,
        statusMessage: mock.statusMessage,
        data: mock.data,
      ),
    );
  }
}

class _MockReply {
  final int? statusCode;
  final dynamic data;
  final String? statusMessage;
  final DioException? error;

  _MockReply({required this.statusCode, this.data, this.statusMessage}) : error = null;
  _MockReply.throwing(this.error)
      : statusCode = null,
        data = null,
        statusMessage = null;
}

void main() {
  late Directory tempDir;
  late MockingInterceptor interceptor;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('auth_service_test_');
    // Initialize the shared HttpClient with a deterministic cookie dir to avoid platform channels.
    await HttpClient.instance.init(baseUrl: 'http://localhost', testCookieDir: tempDir.path);

    // Replace any existing interceptors with our mocking interceptor.
    HttpClient.instance.dio.interceptors.clear();
    interceptor = MockingInterceptor();
    HttpClient.instance.dio.interceptors.add(interceptor);
  });

  tearDown(() async {
    // Clear mocks and cookies between tests for isolation.
    interceptor.replies.clear();
    await HttpClient.instance.clearCookies();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AuthService.signup', () {
    test('returns userId on 201 and success true', () async {
      interceptor.reply('POST', '/api/signup', statusCode: 201, data: {
        'success': true,
        'user_id': 'u1',
      });

      final userId = await AuthService.instance.signup(
        email: 'user@example.com', 
        password: 'pw',
        name: 'Test User',
      );
      expect(userId, 'u1');
    });

    test('throws when 201 but missing/invalid payload', () async {
      interceptor.reply('POST', '/api/signup', statusCode: 201, data: {
        'success': false,
      });

      expect(
        () => AuthService.instance.signup(
          email: 'user@example.com', 
          password: 'pw',
          name: 'Test User',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when non-201 status', () async {
      interceptor.reply('POST', '/api/signup', statusCode: 400, statusMessage: 'Bad Request', data: {
        'error': 'invalid',
      });

      expect(
        () => AuthService.instance.signup(
          email: 'user@example.com', 
          password: 'pw',
          name: 'Test User',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AuthService.login', () {
    test('completes on 200', () async {
      interceptor.reply('POST', '/api/auth/local/login?session=1', statusCode: 200);

      await AuthService.instance.login(email: 'user@example.com', password: 'pw');
    });

    test('throws on non-200', () async {
      interceptor.reply('POST', '/api/auth/local/login?session=1', statusCode: 401, statusMessage: 'Unauthorized');

      expect(
        () => AuthService.instance.login(email: 'user@example.com', password: 'pw'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AuthService.getUserProfile', () {
    test('returns user data on 200', () async {
      interceptor.reply('GET', '/api/v1/user', statusCode: 200, data: {
        'id': 'user123',
        'email': 'user@example.com',
        'name': 'Test User',
      });

      final result = await AuthService.instance.getUserProfile();
      expect(result, isNotNull);
      expect(result!['id'], 'user123');
      expect(result['email'], 'user@example.com');
    });

    test('returns null on 401 unauthorized', () async {
      interceptor.reply('GET', '/api/v1/user', statusCode: 401, statusMessage: 'Unauthorized');

      final result = await AuthService.instance.getUserProfile();
      expect(result, isNull);
    });

    test('returns null on 403 forbidden', () async {
      interceptor.reply('GET', '/api/v1/user', statusCode: 403, statusMessage: 'Forbidden');

      final result = await AuthService.instance.getUserProfile();
      expect(result, isNull);
    });

    test('returns null on network error/exception', () async {
      interceptor.throwError(
        'GET',
        '/api/v1/user',
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/user'),
          type: DioExceptionType.connectionError,
          error: 'connection error',
        ),
      );

      final result = await AuthService.instance.getUserProfile();
      expect(result, isNull);
    });
  });

  group('AuthService.logout', () {
    test('clears persisted cookies', () async {
      final uri = Uri.parse('http://localhost');
      await HttpClient.instance.cookieJar.saveFromResponse(uri, [Cookie('a', 'b')]);

      var loaded = await HttpClient.instance.cookieJar.loadForRequest(uri);
      expect(loaded, isNotEmpty);

      await AuthService.instance.logout();

      loaded = await HttpClient.instance.cookieJar.loadForRequest(uri);
      expect(loaded, isEmpty);
    });
  });
}
