import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show cos, sqrt, asin;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/permissions_handler.dart';

enum RecordingState { idle, recording, paused }

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  RecordingState _recordingState = RecordingState.idle;
  StreamSubscription<Position>? _positionStreamSubscription;

  final List<Position> _recordedPositions = [];
  Position? _lastPosition;

  double _totalDistanceMiles = 0.0;
  int _elapsedSeconds = 0;
  Timer? _timer;

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double _calculatePace() {
    if (_totalDistanceMiles == 0) return 0.0;
    double hours = _elapsedSeconds / 3600.0;
    return _totalDistanceMiles / hours;
  }

  double _calculateDistance(Position start, Position end) {
    const double earthRadiusMiles = 3958.8;

    double lat1 = start.latitude * (3.141592653589793 / 180);
    double lat2 = end.latitude * (3.141592653589793 / 180);
    double lon1 = start.longitude * (3.141592653589793 / 180);
    double lon2 = end.longitude * (3.141592653589793 / 180);

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a =
        (1 - cos(dLat)) / 2 + cos(lat1) * cos(lat2) * (1 - cos(dLon)) / 2;
    double c = 2 * asin(sqrt(a));

    return earthRadiusMiles * c;
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  Future<bool> _checkPermissions() async {
    return await LocationPermissionService.requestLocationPermission(
      context: mounted ? context : null,
    );
  }

  Future<void> _startRecording() async {
    final hasPermission = await _checkPermissions();
    if (!hasPermission) return;

    setState(() {
      _recordingState = RecordingState.recording;
      _recordedPositions.clear();
      _totalDistanceMiles = 0.0;
      _elapsedSeconds = 0;
      _lastPosition = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_recordingState == RecordingState.recording) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });

    LocationSettings locationSettings;

    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
        intervalDuration: const Duration(seconds: 1),
        // Enable background location updates
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Recording your activity",
          notificationTitle: "GPS Tracker",
        ),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        // Enable background location updates
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    final positionStream = GeolocatorPlatform.instance.getPositionStream(
      locationSettings: locationSettings,
    );

    _positionStreamSubscription = positionStream.listen((position) {
      if (_recordingState == RecordingState.recording) {
        setState(() {
          _recordedPositions.add(position);

          if (_lastPosition != null) {
            double distance = _calculateDistance(_lastPosition!, position);
            _totalDistanceMiles += distance;
          }

          _lastPosition = position;
        });
      }
    });
  }

  void _pauseRecording() {
    setState(() {
      _recordingState = RecordingState.paused;
    });
  }

  void _resumeRecording() {
    setState(() {
      _recordingState = RecordingState.recording;
    });
  }

  void _stopRecording() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _finishRecording() async {
    if (_recordingState == RecordingState.recording) {
      _pauseRecording();
    }

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Activity'),
        content: Text(
          'Distance: ${_totalDistanceMiles.toStringAsFixed(2)} miles\n'
          'Time: ${_formatTime(_elapsedSeconds)}\n'
          'Points: ${_recordedPositions.length}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      _stopRecording();
      setState(() {
        _recordingState = RecordingState.idle;
      });

      // Logic here for uploading data

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Activity saved!')));
      }
    }
  }

  Future<void> _discardRecording() async {
    if (_recordingState == RecordingState.recording) {
      _pauseRecording();
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Activity'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (shouldDiscard == true) {
      _stopRecording();
      setState(() {
        _recordingState = RecordingState.idle;
        _recordedPositions.clear();
        _totalDistanceMiles = 0.0;
        _elapsedSeconds = 0;
        _lastPosition = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Tracker'),
        actions: [
          if (_recordingState != RecordingState.idle)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _discardRecording,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Time
            Text(
              _formatTime(_elapsedSeconds),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            // Distance
            Text(
              '${_totalDistanceMiles.toStringAsFixed(2)} mi',
              style: const TextStyle(fontSize: 32),
            ),
            const Text('Distance', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            // Pace
            Text(
              '${_calculatePace().toStringAsFixed(1)} mph',
              style: const TextStyle(fontSize: 32),
            ),
            const Text('Speed', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            // Points
            Text(
              '${_recordedPositions.length}',
              style: const TextStyle(fontSize: 32),
            ),
            const Text('GPS Points', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            // Buttons
            if (_recordingState == RecordingState.idle)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startRecording,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Start', style: TextStyle(fontSize: 18)),
                ),
              ),

            if (_recordingState == RecordingState.recording)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _pauseRecording,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Pause'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _finishRecording,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Finish'),
                    ),
                  ),
                ],
              ),

            if (_recordingState == RecordingState.paused)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _resumeRecording,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Resume'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _finishRecording,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Finish'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
