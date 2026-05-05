import 'dart:developer';

import 'package:intl/intl.dart';

import '../services/http_client.dart';
import 'package:cadent/models/planned_activity.dart';

class PlannedActivityService {
  PlannedActivityService._();

  static final PlannedActivityService instance = PlannedActivityService._();

  Future<bool> createPlannedActivity(PlannedActivity plan) async {
    try {
      final response = await HttpClient.instance.dio.post(
        '/api/v1/activities/plan',
        data: plan.toJson(),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      log('Error creating planned activity: $e');
      return false;
    }
  }

  Future<bool> updatePlannedActivity(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['id'] = id;
      final response = await HttpClient.instance.dio.patch(
        '/api/v1/activities/plan',
        data: updates,
      );

      return response.statusCode == 200;
    } catch (e) {
      log('Error updating planned activity: $e');
      return false;
    }
  }

  Future<bool> deletePlannedActivity(String id) async {
    try {
      final response = await HttpClient.instance.dio.delete(
        '/api/v1/activities/plan',
        data: {'id': id},
      );

      return response.statusCode == 204;
    } catch (e) {
      log('Error deleting planned activity: $e');
      return false;
    }
  }

  /// Returns today's planned activities that have not yet been matched to a completed activity.
  Future<List<PlannedActivity>> getTodayPlannedActivities({
    required DateTime referenceTime,
  }) async {
    try {
      final localReferenceTime = referenceTime.toLocal();
      final response = await HttpClient.instance.dio.get(
        '/api/v1/activities/plan/today',
        queryParameters: {
          'date': DateFormat('yyyy-MM-dd').format(localReferenceTime),
          'timezoneOffsetMinutes': localReferenceTime.timeZoneOffset.inMinutes,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['plannedActivities'] ?? [];
        return data
            .map((e) => PlannedActivity.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      log('Error fetching today planned activities: $e');
      return [];
    }
  }

  /// Links a completed activity to a planned activity.
  Future<bool> matchActivity({
    required String plannedActivityId,
    required String completedActivityId,
  }) async {
    try {
      final response = await HttpClient.instance.dio.patch(
        '/api/v1/activities/plan',
        data: {
          'id': plannedActivityId,
          'matchedActivityId': completedActivityId,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      log('Error matching activity to planned activity: $e');
      return false;
    }
  }
}
