import 'dart:io';

import 'package:cadence/services/activities_service.dart';
import 'package:cadence/models/recording_session_model.dart';
import 'package:cadence/services/http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

/// Simple Dio interceptor to return predefined responses by method + path.
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

/// Captures outgoing request options/data for assertions, then forwards.
class CaptureInterceptor extends Interceptor {
  RequestOptions? lastRequest;
  dynamic lastData;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    lastRequest = options;
    lastData = options.data;
    handler.next(options);
  }

  void reset() {
    lastRequest = null;
    lastData = null;
  }
}

void main() {
  late Directory tempDir;
  late MockingInterceptor mocker;
  late CaptureInterceptor captor;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('activities_service_test_');
    await HttpClient.instance.init(baseUrl: 'http://localhost', testCookieDir: tempDir.path);

    // Replace interceptors with capture + mock (order matters: captor then mocker)
    HttpClient.instance.dio.interceptors.clear();
    captor = CaptureInterceptor();
    mocker = MockingInterceptor();
    HttpClient.instance.dio.interceptors.addAll([captor, mocker]);
  });

  tearDown(() async {
    captor.reset();
    mocker.replies.clear();
    await HttpClient.instance.clearCookies();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ActivitiesService.getActivities', () {
    test('parses list on 200 with activities array', () async {
      mocker.reply('GET', '/v1/activities', statusCode: 200, data: {
        'activities': [
          {
            'id': 'a1',
            'title': 'Morning Run',
            'description': 'Fast 5k',
            'type': 'running',
            'start_time': DateTime.parse('2024-01-01T10:00:00Z').toIso8601String(),
            'processing_ver': 1,
            'created_at': DateTime.parse('2024-01-01T11:00:00Z').toIso8601String(),
            'updated_at': DateTime.parse('2024-01-01T11:00:00Z').toIso8601String(),
          },
          {
            'id': 'a2',
            'title': '',
            'description': '',
            'type': 'road_bike',
            'start_time': DateTime.parse('2024-01-02T10:00:00Z').toIso8601String(),
            'processing_ver': 1,
            'created_at': DateTime.parse('2024-01-02T11:00:00Z').toIso8601String(),
            'updated_at': DateTime.parse('2024-01-02T11:00:00Z').toIso8601String(),
          }
        ],
      });

      final list = await ActivitiesService.instance.getActivities();
      expect(list.length, 2);
      expect(list.first.id, 'a1');
      expect(list.first.activityType, 'running');
      // Second title is empty -> defaults to 'Untitled Activity'
      expect(list[1].title, 'Untitled Activity');
    });

    test('returns [] on unexpected payload shape', () async {
      mocker.reply('GET', '/v1/activities', statusCode: 200, data: {'foo': 'bar'});
      final list = await ActivitiesService.instance.getActivities();
      expect(list, isEmpty);
    });

    test('returns [] on non-200', () async {
      mocker.reply('GET', '/v1/activities', statusCode: 500, statusMessage: 'err');
      final list = await ActivitiesService.instance.getActivities();
      expect(list, isEmpty);
    });

    test('returns [] on network error', () async {
      mocker.throwError(
        'GET',
        '/v1/activities',
        DioException(
          requestOptions: RequestOptions(path: '/v1/activities'),
          type: DioExceptionType.connectionError,
          error: 'offline',
        ),
      );
      final list = await ActivitiesService.instance.getActivities();
      expect(list, isEmpty);
    });
  });

  group('ActivitiesService.saveActivity', () {
    test('returns true on 201 and maps explicit fields', () async {
      mocker.reply('POST', '/v1/activities', statusCode: 201, data: {'ok': true});

      final ok = await ActivitiesService.instance.saveActivity(
        // Use an empty session to avoid geolocator Position construction
        // ignore: invalid_use_of_visible_for_testing_member
        RecordingSessionModel(),
        title: 'My Ride',
        description: 'Fun route',
      );

      expect(ok, isTrue);

      // Assert request path and payload basics
      expect(captor.lastRequest?.path, '/v1/activities');
      final body = (captor.lastData as Map<String, dynamic>);
      expect(body['title'], 'My Ride');
      expect(body['description'], 'Fun route');
      expect(body['activity_type'], isNotEmpty);
      expect(body['client_activity_id'], isA<String>());
      expect(body['samples'], isA<List>());
    });

    test('returns true on 200', () async {
      mocker.reply('POST', '/v1/activities', statusCode: 200, data: {'ok': true});
      final ok = await ActivitiesService.instance.saveActivity(
        RecordingSessionModel(),
      );
      expect(ok, isTrue);
    });

    test('returns false on non-200', () async {
      mocker.reply('POST', '/v1/activities', statusCode: 500);
      final ok = await ActivitiesService.instance.saveActivity(
        RecordingSessionModel(),
      );
      expect(ok, isFalse);
    });

    test('returns false on exception', () async {
      mocker.throwError(
        'POST',
        '/v1/activities',
        DioException(
          requestOptions: RequestOptions(path: '/v1/activities'),
          type: DioExceptionType.connectionError,
          error: 'fail',
        ),
      );
      final ok = await ActivitiesService.instance.saveActivity(
        RecordingSessionModel(),
      );
      expect(ok, isFalse);
    });
  });
}
