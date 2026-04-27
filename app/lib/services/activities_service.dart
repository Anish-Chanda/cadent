import 'dart:developer';

import 'package:uuid/uuid.dart';
import 'package:cadent/models/activity.dart';
import 'package:cadent/models/recording_session_model.dart';
import '../services/http_client.dart';

class ActivitiesService {
  ActivitiesService._();

  static final ActivitiesService instance = ActivitiesService._();

  /// Fetch user's activities from the backend
  Future<List<Activity>> getActivities() async {
    try {
      final response = await HttpClient.instance.dio.get('/api/v1/activities');

      if (response.statusCode == 200) {
        final dynamic responseData = response.data;

        if (responseData is Map && responseData.containsKey('activities')) {
          final List<dynamic> data = responseData['activities'];
          return data.map((activity) => Activity.fromJson(activity)).toList();
        } else {
          log('Unexpected response format: $responseData');
          return [];
        }
      }
      return [];
    } catch (e) {
      log('Error fetching activities: $e');
      return [];
    }
  }

  /// Saves a recorded activity and returns the new activity ID on success, null on failure.
  Future<String?> saveActivity(
    RecordingSessionModel session, {
    String? title,
    String? description,
    int? perceivedEffort,
  }) async {
    try {
      final uuid = Uuid();
      final clientActivityId = uuid.v4();

      // Convert session data to API format
      final activityData = {
        'activity_type': session.activityType.apiName,
        'client_activity_id': clientActivityId,
        'title': title ?? '${session.activityType.displayName} Activity',
        'description':
            description ?? 'Recorded on ${DateTime.now().toIso8601String()}',
        'perceived_effort': perceivedEffort,
        'start_time': session.startTime?.toIso8601String(),
        'samples': session.positions
            .map(
              (position) => {
                'lon': position.longitude,
                'lat': position.latitude,
                't': position.timestamp.millisecondsSinceEpoch,
              },
            )
            .toList(),
      };

      final response = await HttpClient.instance.dio.post(
        '/api/v1/activities',
        data: activityData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['id'] as String?;
      }
      return null;
    } catch (e) {
      log('Error saving activity: $e');
      return null;
    }
  }
}
