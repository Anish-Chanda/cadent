import 'package:geolocator/geolocator.dart';

enum RecordingState { idle, recording, paused, completed }

enum WorkoutType { 
  running('Running', 'running'), 
  roadBiking('Road Biking', 'road_biking');
  
  const WorkoutType(this.displayName, this.apiName);
  final String displayName;
  final String apiName;
}

/// Model class representing a GPS recording session
/// Stores all data related to an ongoing or completed recording
class RecordingSessionModel {
  RecordingState _state;
  final List<Position> _positions;
  double _totalDistanceMeters;
  int _elapsedSeconds;
  DateTime? _startTime;
  Position? _lastPosition;
  WorkoutType _activityType;
  String? _title;
  String? _description;

  RecordingSessionModel({
    RecordingState state = RecordingState.idle,
    List<Position>? positions,
    double totalDistanceMeters = 0.0,
    int elapsedSeconds = 0,
    DateTime? startTime,
    Position? lastPosition,
    WorkoutType activityType = WorkoutType.running,
    String? title,
    String? description,
  })  : _state = state,
        _positions = positions ?? [],
        _totalDistanceMeters = totalDistanceMeters,
        _elapsedSeconds = elapsedSeconds,
        _startTime = startTime,
        _lastPosition = lastPosition,
        _activityType = activityType,
        _title = title,
        _description = description;

  // Getters
  RecordingState get state => _state;
  List<Position> get positions => List.unmodifiable(_positions);
  double get totalDistanceMeters => _totalDistanceMeters;
  int get elapsedSeconds => _elapsedSeconds;
  DateTime? get startTime => _startTime;
  Position? get lastPosition => _lastPosition;
  WorkoutType get activityType => _activityType;
  String? get title => _title;
  String? get description => _description;
  
  // Computed properties
  double get totalDistanceMiles => _totalDistanceMeters * 0.000621371; // Convert meters to miles
  int get pointsCount => _positions.length;
  
  bool get isIdle => _state == RecordingState.idle;
  bool get isRecording => _state == RecordingState.recording;
  bool get isPaused => _state == RecordingState.paused;
  bool get isCompleted => _state == RecordingState.completed;
  bool get isActive => _state == RecordingState.recording || _state == RecordingState.paused;

  /// Current speed calculated from recent GPS positions in meters per second
  /// Uses position-based calculation which would be more accurate than GPS-reported speed
  /// Automatically returns 0 if no recent position updates (user stopped moving)
  double get currentSpeedMs {
    if (_positions.length < 2) return 0.0;
    
    // Check if last position is too old (no recent GPS updates = stationary)
    if (_lastPosition != null) {
      final timeSinceLastPosition = DateTime.now().difference(_lastPosition!.timestamp);
      if (timeSinceLastPosition.inSeconds > 5) {
        return 0.0; // No GPS updates for 5+ seconds = stationary
      }
    }
    
    // Use the last few positions to calculate average speed over recent time
    const int sampleSize = 5; // Use last 5 positions for better accuracy
    final int startIndex = (_positions.length - sampleSize).clamp(0, _positions.length - 1);
    final recentPositions = _positions.sublist(startIndex);
    
    if (recentPositions.length < 2) return 0.0;
    
    final firstPos = recentPositions.first;
    final lastPos = recentPositions.last;
    
    // Calculate time difference in seconds
    final timeDiff = lastPos.timestamp.difference(firstPos.timestamp).inMilliseconds / 1000.0;
    if (timeDiff <= 0 || timeDiff < 2.0) return 0.0; // Need at least 2 seconds
    
    // Calculate distance
    final distance = Geolocator.distanceBetween(
      firstPos.latitude,
      firstPos.longitude,
      lastPos.latitude,
      lastPos.longitude,
    );
    
    // If very small distance, consider as stationary... so its not super twitchy?
    if (distance < 1.0) return 0.0; // Less than 1 meter = stationary
    
    // Calculate speed in m/s
    final speedMs = distance / timeDiff;
    
    // Apply minimum threshold for stationary detection (0.2 m/s ≈ 0.45 mph)
    if (speedMs < 0.2) return 0.0; // Below 0.2 m/s = stationary
    
    return speedMs;
  }

  /// Current speed in miles per hour (converted from m/s for display)
  double get currentSpeedMph => currentSpeedMs * 2.237;

  /// Format elapsed time as HH:MM:SS
  String get formattedTime {
    int hours = _elapsedSeconds ~/ 3600;
    int minutes = (_elapsedSeconds % 3600) ~/ 60;
    int secs = _elapsedSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Format distance with appropriate precision
  String get formattedDistance {
    return '${totalDistanceMiles.toStringAsFixed(2)} mi';
  }

  /// Format current speed with appropriate precision
  String get formattedSpeed {
    return '${currentSpeedMph.toStringAsFixed(1)} mph';
  }

  // State mutation methods (should only be called by the controller)
  void _setState(RecordingState newState) {
    _state = newState;
  }

  void _addPosition(Position position) {
    _positions.add(position);
    _lastPosition = position;
  }

  void _addDistance(double distanceMeters) {
    _totalDistanceMeters += distanceMeters;
  }

  void _incrementTime() {
    _elapsedSeconds++;
  }

  void _setStartTime(DateTime time) {
    _startTime = time;
  }

  void _setActivityType(WorkoutType activityType) {
    _activityType = activityType;
  }

  void _setTitle(String? title) {
    _title = title;
  }

  void _setDescription(String? description) {
    _description = description;
  }

  void _reset() {
    _state = RecordingState.idle;
    _positions.clear();
    _totalDistanceMeters = 0.0;
    _elapsedSeconds = 0;
    _startTime = null;
    _lastPosition = null;
    _activityType = WorkoutType.running;
    _title = null;
    _description = null;
  }

  // Factory methods for controller access
  static RecordingSessionModel createIdle() {
    return RecordingSessionModel();
  }

  /// Returns a copy of the model with updated fields
  RecordingSessionModel copyWith({
    RecordingState? state,
    List<Position>? positions,
    double? totalDistanceMeters,
    int? elapsedSeconds,
    DateTime? startTime,
    Position? lastPosition,
    WorkoutType? activityType,
    String? title,
    String? description,
  }) {
    return RecordingSessionModel(
      state: state ?? _state,
      positions: positions ?? List.from(_positions),
      totalDistanceMeters: totalDistanceMeters ?? _totalDistanceMeters,
      elapsedSeconds: elapsedSeconds ?? _elapsedSeconds,
      startTime: startTime ?? _startTime,
      lastPosition: lastPosition ?? _lastPosition,
      activityType: activityType ?? _activityType,
      title: title ?? _title,
      description: description ?? _description,
    );
  }

  /// Creates a summary for saving the activity
  Map<String, dynamic> toActivitySummary() {
    return {
      'activity_type': _activityType.name,
      'title': _title,
      'description': _description,
      'positions': _positions.length,
      'distance_meters': _totalDistanceMeters,
      'distance_miles': totalDistanceMiles,
      'elapsed_seconds': _elapsedSeconds,
      'formatted_time': formattedTime,
      'formatted_distance': formattedDistance,
      'start_time': _startTime?.toIso8601String(),
      'gps_points': _positions.map((p) => {
        'lat': p.latitude,
        'lon': p.longitude,
        'timestamp': p.timestamp.millisecondsSinceEpoch,
        'accuracy': p.accuracy,
        'altitude': p.altitude,
        'speed': p.speed,
      }).toList(),
    };
  }
}

/// Internal controller interface for model mutations
/// This should only be used by the RecordingController
mixin RecordingSessionModelController on RecordingSessionModel {
  void setState(RecordingState newState) => _setState(newState);
  void addPosition(Position position) => _addPosition(position);
  void addDistance(double distanceMeters) => _addDistance(distanceMeters);
  void incrementTime() => _incrementTime();
  void setStartTime(DateTime time) => _setStartTime(time);
  void setActivityType(WorkoutType activityType) => _setActivityType(activityType);
  void setTitle(String? title) => _setTitle(title);
  void setDescription(String? description) => _setDescription(description);
  void reset() => _reset();
}
