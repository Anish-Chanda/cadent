import 'dart:developer';
import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../models/planned_activity.dart';
import '../services/calendar_service.dart';

enum CalendarLoadingState {
  idle,
  loading,
  loaded,
  error,
}

class CalendarProvider with ChangeNotifier {
  final CalendarService _calendarService = CalendarService.instance;

  List<Activity> _activities = [];
  List<PlannedActivity> _plannedActivities = [];
  CalendarLoadingState _loadingState = CalendarLoadingState.idle;
  String? _errorMessage;

  /// The date range currently loaded.
  DateTime? _loadedStart;
  DateTime? _loadedEnd;

  // Getters
  List<Activity> get activities => _activities;
  List<PlannedActivity> get plannedActivities => _plannedActivities;
  CalendarLoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loadingState == CalendarLoadingState.loading;
  bool get hasError => _loadingState == CalendarLoadingState.error;

  /// Load calendar data for [startDate]..[endDate].
  /// Skips the network call if the requested range is already loaded.
  Future<void> loadCalendar(DateTime startDate, DateTime endDate) async {
    if (_loadingState == CalendarLoadingState.loading) return;

    // Skip if the same range is already loaded.
    if (_loadingState == CalendarLoadingState.loaded &&
        _loadedStart != null &&
        _loadedEnd != null &&
        !startDate.isBefore(_loadedStart!) &&
        !endDate.isAfter(_loadedEnd!)) {
      return;
    }

    _setLoadingState(CalendarLoadingState.loading);
    _clearError();

    try {
      final data = await _calendarService.getCalendar(startDate, endDate);
      _activities = data.activities;
      _plannedActivities = data.plannedActivities;
      _loadedStart = startDate;
      _loadedEnd = endDate;
      _setLoadingState(CalendarLoadingState.loaded);
      log('Calendar loaded: ${_activities.length} activities, '
          '${_plannedActivities.length} planned for $startDate–$endDate');
    } catch (e) {
      _setError('Failed to load calendar: ${e.toString()}');
      log('Error loading calendar: $e');
    }
  }

  /// Force a refresh of the currently loaded date range.
  Future<void> refresh() async {
    if (_loadedStart == null || _loadedEnd == null) return;
    final start = _loadedStart!;
    final end = _loadedEnd!;
    _loadedStart = null;
    _loadedEnd = null;
    await loadCalendar(start, end);
  }

  /// Injects a mock planned activity for development/UI testing purposes.
  void injectMockPlannedActivity() {
    final today = DateTime.now();
    _plannedActivities = [
      PlannedActivity(
        id: 'mock-1',
        title: 'Morning Run',
        description: 'Easy 5k recovery run',
        activityType: 'running',
        startTime: DateTime(today.year, today.month, today.day, 8, 0),
        plannedDistanceMeter: 5000.0,
        plannedDurationSecond: 1800,
        plannedElevationGainMeter: 50.0,
        targetAverageSpeedMeterPerSecond: 2.78,
      ),
    ];
    _loadingState = CalendarLoadingState.loaded;
    notifyListeners();
  }

  /// Clear all calendar data (e.g. on logout).
  void clear() {
    _activities = [];
    _plannedActivities = [];
    _loadedStart = null;
    _loadedEnd = null;
    _setLoadingState(CalendarLoadingState.idle);
    _clearError();
  }

  /// Returns completed activities on [date].
  List<Activity> activitiesForDate(DateTime date) {
    return _activities.where((a) => _sameDay(a.startTime, date)).toList();
  }

  /// Returns planned activities on [date].
  List<PlannedActivity> plannedForDate(DateTime date) {
    return _plannedActivities
        .where((p) => _sameDay(p.startTime, date))
        .toList();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _setLoadingState(CalendarLoadingState state) {
    _loadingState = state;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _setLoadingState(CalendarLoadingState.error);
  }

  void _clearError() {
    _errorMessage = null;
  }
}
