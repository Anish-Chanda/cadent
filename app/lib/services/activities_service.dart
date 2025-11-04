import 'dart:developer';
import '../models/activity.dart';
import '../services/http_client.dart';

class ActivitiesService {
  ActivitiesService._();

  static final ActivitiesService instance = ActivitiesService._();

  /// Fetch user's activities from the backend
  Future<List<Activity>> getActivities() async {
    try {
      final dio = HttpClient.instance.dio;
      final response = await dio.get('/v1/activities');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data.map((json) => Activity.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to load activities: ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching activities: $e');
      rethrow;
    }
  }
}