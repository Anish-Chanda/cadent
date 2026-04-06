import 'dart:developer';

import 'package:cadent/models/activity.dart';
import 'package:cadent/models/planned_activity.dart';
import '../services/http_client.dart';

class CalendarData {
  final List<Activity> activities;
  final List<PlannedActivity> plannedActivities;

  const CalendarData({
    required this.activities,
    required this.plannedActivities,
  });
}

class CalendarService {
  CalendarService._();

  static final CalendarService instance = CalendarService._();

  /// Fetch activities and planned activities for a date range from the backend.
  /// Dates are formatted as YYYY-MM-DD.
  Future<CalendarData> getCalendar(DateTime startDate, DateTime endDate) async {
    final start = _formatDate(startDate);
    final end = _formatDate(endDate);

    try {
      final response = await HttpClient.instance.dio.get(
        '/api/v1/activities/calendar',
        queryParameters: {'startDate': start, 'endDate': end},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        final activities = (data['activities'] as List<dynamic>)
            .map((a) => Activity.fromJson(a as Map<String, dynamic>))
            .toList();

        final plannedActivities = (data['planned_activities'] as List<dynamic>)
            .map((p) => PlannedActivity.fromCalendarJson(p as Map<String, dynamic>))
            .toList();

        return CalendarData(
          activities: activities,
          plannedActivities: plannedActivities,
        );
      }

      log('Unexpected status code from calendar API: ${response.statusCode}');
      return const CalendarData(activities: [], plannedActivities: []);
    } catch (e) {
      log('Error fetching calendar data: $e');
      rethrow;
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
