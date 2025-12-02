import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// TODO: add interceptors to handle 401 responses globally and attempt token refreshes
class HttpClient {
  HttpClient._();

  // MODIFIED: Make instance replaceable for testing
  static HttpClient _instance = HttpClient._();
  static HttpClient get instance => _instance;

  // ADDED: Reset instance for testing
  @visibleForTesting
  static void resetInstance() {
    _instance = HttpClient._();
  }

  late Dio dio;
  // This can remain late final because we create a new HttpClient instance for each test
  late final PersistCookieJar cookieJar;
  late String cookiePath;
  bool cookieJarInitialized = false;

  Future<void> init({required String baseUrl, String? testCookieDir}) async {
    if (!cookieJarInitialized) {
      //figure out cookie path
      cookiePath = testCookieDir ??
          (await (() async {
            final appDocDir = await getApplicationDocumentsDirectory();
            return '${appDocDir.path}/.cookies/';
          })());

      //create persistant cookie jar
      cookieJar = PersistCookieJar(
        ignoreExpires: false,
        storage: FileStorage(cookiePath),
      );
      cookieJarInitialized = true;
    }

    //create dio with base url
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      ),
    );

    dio.interceptors.add(CookieManager(cookieJar));
  }

  Future<void> clearCookies() async {
    await cookieJar.deleteAll();
  }
}
