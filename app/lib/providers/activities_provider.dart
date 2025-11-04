import 'dart:developer';
import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../services/activities_service.dart';

enum ActivitiesLoadingState {
  idle,
  loading,
  loaded,
  error,
}

class ActivitiesProvider with ChangeNotifier {
  final ActivitiesService _activitiesService = ActivitiesService.instance;

  List<Activity> _activities = [];
  ActivitiesLoadingState _loadingState = ActivitiesLoadingState.idle;
  String? _errorMessage;
  DateTime? _lastRefreshTime;
  static const Duration _refreshCooldown = Duration(seconds: 1);

  // Getters
  List<Activity> get activities => _activities;
  ActivitiesLoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loadingState == ActivitiesLoadingState.loading;
  bool get hasError => _loadingState == ActivitiesLoadingState.error;
  bool get isEmpty => _activities.isEmpty && _loadingState == ActivitiesLoadingState.loaded;

  // Load activities from the backend
  Future<void> loadActivities() async {
    if (_loadingState == ActivitiesLoadingState.loading) return; // Prevent multiple simultaneous loads

    // Add debouncing protection
    final now = DateTime.now();
    if (_lastRefreshTime != null && 
        now.difference(_lastRefreshTime!) < _refreshCooldown) {
      return; // Too soon, ignore request
    }
    
    _lastRefreshTime = now;
    _setLoadingState(ActivitiesLoadingState.loading);
    _clearError();

    try {
      final activities = await _activitiesService.getActivities();
      _activities = activities;
      _setLoadingState(ActivitiesLoadingState.loaded);
      log('Successfully loaded ${activities.length} activities');
    } catch (e) {
      _setError('Failed to load activities: ${e.toString()}');
      log('Error loading activities: $e');
    }
  }

  // Refresh activities (pull to refresh functionality)
  Future<void> refreshActivities() async {
    await loadActivities();
  }

  // Clear all activities (for logout or reset)
  void clearActivities() {
    _activities = [];
    _setLoadingState(ActivitiesLoadingState.idle);
    _clearError();
  }

  // Get activity by ID
  Activity? getActivityById(String id) {
    try {
      return _activities.firstWhere((activity) => activity.id == id);
    } catch (e) {
      return null;
    }
  }

  // Filter activities by type
  List<Activity> getActivitiesByType(String type) {
    return _activities.where((activity) => activity.activityType == type).toList();
  }

  // Get recent activities (last N activities)
  List<Activity> getRecentActivities({int limit = 10}) {
    final sortedActivities = List<Activity>.from(_activities);
    sortedActivities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedActivities.take(limit).toList();
  }

  // Private helper methods
  void _setLoadingState(ActivitiesLoadingState state) {
    _loadingState = state;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _setLoadingState(ActivitiesLoadingState.error);
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Retry loading after error
  Future<void> retry() async {
    if (_loadingState == ActivitiesLoadingState.error) {
      await loadActivities();
    }
  }
}