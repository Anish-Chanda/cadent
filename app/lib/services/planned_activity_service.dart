import 'dart:developer';

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

  Future<bool> updatePlannedActivity(String id, Map<String, dynamic> updates) async {
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
}
