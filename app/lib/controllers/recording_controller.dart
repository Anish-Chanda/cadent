import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/recording_session_model.dart';
import '../services/permissions_handler.dart';

/// Controller class that handles all GPS recording logic
class RecordingController extends ChangeNotifier {
  RecordingSessionModel _model = RecordingSessionModel.createIdle();
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _timer;

  // Getters for the view
  RecordingSessionModel get model => _model;

  @override
  void dispose() {
    _stopLocationTracking();
    _stopTimer();
    super.dispose();
  }

  /// Starts a new recording session
  Future<bool> startRecording({BuildContext? context}) async {
    try {
      // Check location permissions first
      final hasPermission = await LocationPermissionService.requestLocationPermission(
        context: context,
      );
      if (!hasPermission) return false;

      // Preserve activity type when starting a new recording
      final currentActivityType = _model.activityType;
      _resetModel();
      
      // Restore the activity type before updating state to avoid notifying with wrong type
      _model = _model.copyWith(activityType: currentActivityType);
      
      _updateModelState(RecordingState.recording);
      _setStartTime(DateTime.now());
      
      log('Started recording: ${_model.activityType.displayName}');

      // Start the timer for elapsed time
      _startTimer();

      // Start GPS tracking
      await _startLocationTracking();

      return true;
    } catch (e) {
      log('Error starting recording: $e');
      return false;
    }
  }

  /// Pauses the current recording
  void pauseRecording() {
    if (!_model.isRecording) return;
    
    _updateModelState(RecordingState.paused);
    notifyListeners();
  }

  /// Resumes a paused recording
  void resumeRecording() {
    if (!_model.isPaused) return;
    
    _updateModelState(RecordingState.recording);
    notifyListeners();
  }

  /// Finishes the current recording and moves to completed state
  void finishRecording() {
    if (!_model.isActive) return;

    // Stop all tracking
    _stopLocationTracking();
    _stopTimer();

    // Move to completed state for final review
    _updateModelState(RecordingState.completed);
    
    log('Recording finished: ${_model.activityType.displayName} - ${_model.formattedTime} - ${_model.formattedDistance} - ${_model.positions.length} GPS points');
  }

  /// Gets the activity data for saving (only available in completed state)
  Map<String, dynamic>? getActivityData() {
    if (!_model.isCompleted) return null;
    return _model.toActivitySummary();
  }

  /// Resets to idle state (after saving or discarding completed recording)
  void resetToIdle() {
    // Preserve the activity type when resetting
    final currentActivityType = _model.activityType;
    _resetModel();
    _updateModelState(RecordingState.idle);
    // Set the activity type back to what it was
    _model = _model.copyWith(activityType: currentActivityType);
    notifyListeners();
  }

  /// Updates the activity type (only allowed when idle)
  void setActivityType(WorkoutType activityType) {
    if (_model.isIdle) {
      _model = _model.copyWith(activityType: activityType);
      log('Activity type changed to: ${_model.activityType.displayName}');
      notifyListeners();
    }
  }

  /// Discards the current recording
  void discardRecording() {
    _stopLocationTracking();
    _stopTimer();
    _resetModel();
    _updateModelState(RecordingState.idle);
  }

  /// Resume recording from completed state (go back to paused state)
  Future<void> resumeFromFinished() async {
    if (!_model.isCompleted) return;
    
    // Move back to paused state so user can resume or make changes
    _updateModelState(RecordingState.paused);
    
    // Restart the timer to continue tracking elapsed time
    _startTimer();
    
    // Restart GPS location tracking so we can continue recording when they hit resume
    await _startLocationTracking();
    
    log('Resumed from finished: ${_model.activityType.displayName}');
  }

  /// Private method to reset the model
  void _resetModel() {
    _model = RecordingSessionModel.createIdle();
  }

  /// Private method to update model state
  void _updateModelState(RecordingState newState) {
    _model = _model.copyWith(state: newState);
    notifyListeners();
  }

  /// Private method to set start time
  void _setStartTime(DateTime time) {
    _model = _model.copyWith(startTime: time);
  }

  /// Starts the timer for elapsed time tracking
  void _startTimer() {
    _stopTimer(); // Ensure no duplicate timers
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_model.isRecording) {
        _model = _model.copyWith(elapsedSeconds: _model.elapsedSeconds + 1);
        notifyListeners();
      }
    });
  }

  /// Stops the timer
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }



  /// Starts GPS location tracking with optimized settings
  Future<void> _startLocationTracking() async {
    _stopLocationTracking(); // Ensure no duplicate streams

    final locationSettings = _createLocationSettings();
    
    try {
      final positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      );

      _positionStreamSubscription = positionStream.listen(
        _onLocationUpdate,
        onError: (error) {
          log('GPS tracking error: $error');
        },
      );
    } catch (e) {
      log('Failed to start location tracking: $e');
    }
  }

  /// Stops GPS location tracking
  void _stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Creates optimized location settings based on platform
  /// Configured for ~1Hz recording like bike computers and running watches
  /// 
  /// Android: 1Hz updates via intervalDuration
  /// iOS: 1-5Hz updates (native GPS rate) since iOS doesn't support intervalDuration
  LocationSettings _createLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // No distance filter - record based on time
        intervalDuration: const Duration(seconds: 1), // 1Hz recording
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Recording your activity",
          notificationTitle: "Cadent GPS Tracker",
        ),
      );
    } else if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // No distance filter - iOS will use native GPS rate (1-5Hz)
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      // Only Android and iOS are supported for GPS tracking
      throw UnsupportedError('GPS tracking is only supported on Android and iOS platforms');
    }
  }  /// Handles new GPS location updates
  void _onLocationUpdate(Position position) {
    if (!_model.isRecording) return;

    try {
      final positions = List<Position>.from(_model.positions);
      positions.add(position);

      double totalDistance = _model.totalDistanceMeters;
      Position? lastPosition = _model.lastPosition;

      // Calculate distance from last position
      if (lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          lastPosition.latitude,
          lastPosition.longitude,
          position.latitude,
          position.longitude,
        );
        totalDistance += distance;
      }

      // Update model using copyWith for consistency
      _model = _model.copyWith(
        positions: positions,
        totalDistanceMeters: totalDistance,
        lastPosition: position,
      );

      notifyListeners();
    } catch (e) {
      log('Error processing location update: $e');
    }
  }

  /// Checks if the current recording has meaningful data
  bool hasMinimumData() {
    return _model.pointsCount >= 2 && _model.totalDistanceMeters > 10; // At least 10 meters
  }
}