// test/services/http_client_test.dart

import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:cadence/services/http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Import the generated mocks
import 'http_client_test.mocks.dart';

// Create a fake PathProviderPlatform for testing
class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '/fake/path';
  }
}

// Generate mocks for Dio
@GenerateMocks([Dio])
void main() {
  late HttpClient httpClient;
  const String baseUrl = 'https://api.example.com';
  const String testCookieDir = '/test/cookies';

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = FakePathProviderPlatform();
  });

  setUp(() {
    // FIX: Reset the singleton instance before each test for true isolation.
    HttpClient.resetInstance();
    httpClient = HttpClient.instance;
  });

  group('HttpClient Tests', () {
    test('init should correctly configure Dio and CookieJar with testCookieDir', () async {
      // Act
      await httpClient.init(baseUrl: baseUrl, testCookieDir: testCookieDir);

      // Assert
      expect(httpClient.dio, isA<Dio>());
      expect(httpClient.dio.options.baseUrl, baseUrl);
      expect(httpClient.dio.options.headers[HttpHeaders.contentTypeHeader], 'application/json');
      expect(httpClient.dio.interceptors, isNotEmpty);
      expect(httpClient.cookiePath, testCookieDir);
      expect(httpClient.cookieJarInitialized, isTrue);
    });

    test('init should use path_provider when testCookieDir is null', () async {
      // Act
      await httpClient.init(baseUrl: baseUrl);

      // Assert
      final expectedPath = '/fake/path/.cookies/';
      expect(httpClient.cookiePath, expectedPath);
    });

    test('clearCookies should call cookieJar.deleteAll', () async {
      // Arrange: Ensure client is initialized
      await httpClient.init(baseUrl: baseUrl, testCookieDir: testCookieDir);

      final testUri = Uri.parse(baseUrl);
      final cookie = Cookie('test', 'value');
      await httpClient.cookieJar.saveFromResponse(testUri, [cookie]);

      var cookies = await httpClient.cookieJar.loadForRequest(testUri);
      expect(cookies, isNotEmpty);

      // Act
      await httpClient.clearCookies();

      // Assert
      cookies = await httpClient.cookieJar.loadForRequest(testUri);
      expect(cookies, isEmpty);
    });
  });
}
