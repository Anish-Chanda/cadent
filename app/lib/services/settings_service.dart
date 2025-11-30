import 'dart:developer';

import '../services/http_client.dart';
import '../models/user_profile.dart';

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  /// Fetch user profile from the backend
  Future<UserProfile?> getUserProfile() async {
    try {
      final response = await HttpClient.instance.dio.get('/v1/user');

      if (response.statusCode == 200) {
        final dynamic responseData = response.data;

        if (responseData is Map<String, dynamic>) {
          return UserProfile.fromJson(responseData);
        } else {
          log('Unexpected response format: $responseData');
          return null;
        }
      }
      return null;
    } catch (e) {
      log('Error fetching user profile: $e');
      return null;
    }
  }

  /// Get user's name (convenience method)
  Future<String> getName() async {
    try {
      final profile = await getUserProfile();
      return profile?.name ?? "";
    } catch (e) {
      log('Error fetching name: $e');
      return "";
    }
  }

  Future<bool> saveName(String newName) async {
    try {
      final response = await HttpClient.instance.dio.patch(
        '/v1/user', 
        data: {'name': newName}
      );

      return response.statusCode == 200;
    } catch (e) {
      log('Error updating name: $e');
      return false;
    }
  }

  Future<UserProfile?> updateUserProfile({String? name, String? email}) async {
    try {
      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;

      if (updates.isEmpty) {
        log('No updates provided');
        return null;
      }

      final response = await HttpClient.instance.dio.patch(
        '/v1/user',
        data: updates,
      );

      if (response.statusCode == 200) {
        final dynamic responseData = response.data;
        if (responseData is Map<String, dynamic>) {
          return UserProfile.fromJson(responseData);
        }
      }
      return null;
    } catch (e) {
      log('Error updating user profile: $e');
      return null;
    }
  }
}