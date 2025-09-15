import 'dart:io';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

class HttpClient {
  HttpClient._();

  static final HttpClient instance = HttpClient._();

  late Dio dio;
  late final PersistCookieJar cookieJar;
  bool _cookieJarInitialized = false;

  Future<void> init({required String baseUrl, String? testCookieDir}) async {
    if (!_cookieJarInitialized) {
      //figure out cookie path
      final cookiesPath =
          testCookieDir ??
          (await (() async {
            final appDocDir = await getApplicationDocumentsDirectory();
            return '${appDocDir.path}/.cookies/';
          })());

      //create persistant cookie jar
      cookieJar = PersistCookieJar(
        ignoreExpires: false,
        storage: FileStorage(cookiesPath),
      );
      _cookieJarInitialized = true;
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
