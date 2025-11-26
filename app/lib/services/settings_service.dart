import 'dart:developer';

import '../services/http_client.dart';

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  /// Fetch user's name from the backend
  Future<String> getName() async {
    try {
      final response = await HttpClient.instance.dio.get('/v1/name');

      if (response.statusCode == 200) {
        final dynamic responseData = response.data;

        if (responseData is String) {
          return responseData;
        } else {
          log('Unexpected response format: $responseData');
          return "";
        }
      }
      return "";
    } catch (e) {
      log('Error fetching activities: $e');
      return "";
    }
  }

  Future<bool> saveName(String newName) async {
    try {

      final response = await HttpClient.instance.dio.post('/v1/changeName', data: {'newName': newName});

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      log('Error saving activity: $e');
      return false;
    }
  }
}