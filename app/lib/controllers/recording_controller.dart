import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/recording_session_model.dart';
import '../services/android_activity_tracking_service.dart';
import '../services/permissions_handler.dart';

/// Controller class that handles all GPS recording logic
class RecordingController extends ChangeNotifier {
  RecordingSessionModel _model = RecordingSessionModel.createIdle();
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<Map<String, dynamic>>? _androidTrackingSubscription;
  Timer? _timer;
  double _androidDistanceOffsetMeters = 0.0;
  int _androidElapsedOffsetSeconds = 0;
  bool _useMetricUnits = true;

  // Getters for the view
  RecordingSessionModel get model => _model;

  @override
  void dispose() {
    _detachLocationTracking();
    _stopTimer();
    super.dispose();
  }

  /// Reattaches to an Android foreground tracking service that survived while
  /// the Flutter UI was not running.
  Future<void> restoreBackgroundTracking() async {
    if (!AndroidActivityTrackingService.isSupported) return;

    _listenToAndroidTrackingEvents();
    final snapshot = await AndroidActivityTrackingService.getSnapshot();
    if (snapshot != null) {
      _applyAndroidSnapshot(snapshot, includePositions: true);
    }
  }

  /// Starts a new recording session
  Future<bool> startRecording({
    BuildContext? context,
    bool useMetricUnits = true,
  }) async {
    try {
      // Check location permissions first
      final hasPermission =
          await LocationPermissionService.requestLocationPermission(
            context: context,
            requirePrecise: true,
          );
      if (!hasPermission) return false;
      if (context != null && !context.mounted) return false;

      final hasNotificationPermission =
          await LocationPermissionService.requestTrackingNotificationPermission(
            context: context,
          );
      if (!hasNotificationPermission) return false;
      _useMetricUnits = useMetricUnits;

      // Preserve activity type when starting a new recording
      final currentActivityType = _model.activityType;
      _resetModel();
      _androidDistanceOffsetMeters = 0.0;
      _androidElapsedOffsetSeconds = 0;

      // Restore the activity type before updating state to avoid notifying with wrong type
      _model = _model.copyWith(activityType: currentActivityType);

      _updateModelState(RecordingState.recording);
      _setStartTime(DateTime.now());

      log('Started recording: ${_model.activityType.displayName}');

      if (!AndroidActivityTrackingService.isSupported) {
        // Android elapsed time is driven by the foreground tracking service so
        // the notification and UI stay in sync.
        _startTimer();
      }

      // Start GPS tracking
      await _startLocationTracking(useMetricUnits: useMetricUnits);

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
    if (AndroidActivityTrackingService.isSupported) {
      AndroidActivityTrackingService.pause();
    }
    notifyListeners();
  }

  /// Resumes a paused recording
  void resumeRecording() {
    if (!_model.isPaused) return;

    _updateModelState(RecordingState.recording);
    if (AndroidActivityTrackingService.isSupported) {
      AndroidActivityTrackingService.resume();
    }
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

    log(
      'Recording finished: ${_model.activityType.displayName} - ${_model.formattedTime} - ${_model.totalDistanceMeters.toStringAsFixed(0)}m - ${_model.positions.length} GPS points',
    );
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
    _androidDistanceOffsetMeters = 0.0;
    _androidElapsedOffsetSeconds = 0;
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
    _androidDistanceOffsetMeters = 0.0;
    _androidElapsedOffsetSeconds = 0;
    _resetModel();
    _updateModelState(RecordingState.idle);
  }

  /// Resume recording from completed state (go back to paused state)
  Future<void> resumeFromFinished() async {
    if (!_model.isCompleted) return;

    // Move back to paused state so user can resume or make changes
    _androidDistanceOffsetMeters = _model.totalDistanceMeters;
    _androidElapsedOffsetSeconds = _model.elapsedSeconds;
    _updateModelState(RecordingState.paused);

    if (!AndroidActivityTrackingService.isSupported) {
      // Restart the timer to continue tracking elapsed time
      _startTimer();
    }

    // Restart GPS location tracking so we can continue recording when they hit resume
    await _startLocationTracking(useMetricUnits: _useMetricUnits);

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
  Future<void> _startLocationTracking({bool useMetricUnits = true}) async {
    if (AndroidActivityTrackingService.isSupported) {
      _androidTrackingSubscription?.cancel();
      _androidTrackingSubscription = null;
      _listenToAndroidTrackingEvents();
      await AndroidActivityTrackingService.start(
        activityType: _model.activityType.apiName,
        activityName: _model.activityType.displayName,
        useMetricUnits: useMetricUnits,
      );
      return;
    }

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
    if (AndroidActivityTrackingService.isSupported) {
      AndroidActivityTrackingService.stop();
      _androidTrackingSubscription?.cancel();
      _androidTrackingSubscription = null;
      return;
    }

    _detachLocationTracking();
  }

  void _detachLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _androidTrackingSubscription?.cancel();
    _androidTrackingSubscription = null;
  }

  void _listenToAndroidTrackingEvents() {
    _androidTrackingSubscription ??= AndroidActivityTrackingService.events
        .listen(
          _applyAndroidSnapshot,
          onError: (error) {
            log('Android tracking event error: $error');
          },
        );
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
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'Recording ${_model.activityType.displayName}',
          notificationText:
              'GPS tracking stays active while the screen is off. Return to Cadent to pause or finish.',
          notificationChannelName: 'Activity tracking',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter:
            0, // No distance filter - iOS will use native GPS rate (1-5Hz)
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      // Only Android and iOS are supported for GPS tracking
      throw UnsupportedError(
        'GPS tracking is only supported on Android and iOS platforms',
      );
    }
  }

  /// Handles new GPS location updates
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

  void _applyAndroidSnapshot(
    Map<String, dynamic> snapshot, {
    bool includePositions = false,
  }) {
    try {
      final isRecording = snapshot['isRecording'] == true;
      final isPaused = snapshot['isPaused'] == true;
      final lastPosition = _positionFromNativeMap(snapshot['lastPosition']);
      final positions = includePositions
          ? _positionsFromNativeList(snapshot['positions'])
          : _appendNativePosition(lastPosition);

      _model = _model.copyWith(
        state: isRecording
            ? RecordingState.recording
            : isPaused
            ? RecordingState.paused
            : _model.state,
        positions: positions,
        totalDistanceMeters:
            ((snapshot['distanceMeters'] as num?)?.toDouble() ??
                _model.totalDistanceMeters) +
            _androidDistanceOffsetMeters,
        elapsedSeconds:
            ((snapshot['elapsedSeconds'] as num?)?.toInt() ??
                _model.elapsedSeconds) +
            _androidElapsedOffsetSeconds,
        startTime:
            _model.startTime ??
            _dateTimeFromNativeMs(snapshot['startTimestamp']),
        lastPosition: lastPosition ?? _model.lastPosition,
      );
      notifyListeners();
    } catch (e) {
      log('Error applying Android tracking snapshot: $e');
    }
  }

  List<Position> _appendNativePosition(Position? position) {
    if (position == null) return _model.positions;

    final positions = List<Position>.from(_model.positions);
    final hasSameLatestPoint =
        positions.isNotEmpty &&
        positions.last.timestamp == position.timestamp &&
        positions.last.latitude == position.latitude &&
        positions.last.longitude == position.longitude;

    if (!hasSameLatestPoint) {
      positions.add(position);
    }

    return positions;
  }

  List<Position> _positionsFromNativeList(Object? nativePositions) {
    if (nativePositions is! List) return _model.positions;

    return nativePositions
        .map(_positionFromNativeMap)
        .whereType<Position>()
        .toList();
  }

  Position? _positionFromNativeMap(Object? nativePosition) {
    if (nativePosition is! Map) return null;

    final position = Map<dynamic, dynamic>.from(nativePosition);
    final timestampMs = (position['timestamp'] as num?)?.toInt();
    final latitude = (position['lat'] as num?)?.toDouble();
    final longitude = (position['lon'] as num?)?.toDouble();
    if (timestampMs == null || latitude == null || longitude == null) {
      return null;
    }

    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      accuracy: (position['accuracy'] as num?)?.toDouble() ?? 0.0,
      altitude: (position['altitude'] as num?)?.toDouble() ?? 0.0,
      altitudeAccuracy: 0.0,
      heading: (position['heading'] as num?)?.toDouble() ?? 0.0,
      headingAccuracy: 0.0,
      speed: (position['speed'] as num?)?.toDouble() ?? 0.0,
      speedAccuracy: 0.0,
    );
  }

  DateTime? _dateTimeFromNativeMs(Object? timestamp) {
    final timestampMs = (timestamp as num?)?.toInt();
    if (timestampMs == null || timestampMs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestampMs);
  }

  /// Checks if the current recording has meaningful data
  bool hasMinimumData() {
    return _model.pointsCount >= 2 &&
        _model.totalDistanceMeters > 10; // At least 10 meters
  }
}
