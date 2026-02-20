import 'dart:developer';

import 'package:cadence/services/background_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../controllers/recording_controller.dart';
import '../models/recording_session_model.dart';
import '../services/activities_service.dart';
import '../widgets/recorder/recording_map_view.dart';
import '../widgets/recorder/recording_status_bar.dart';
import '../widgets/recorder/recording_floating_card.dart';
import '../widgets/recorder/recording_stats_compact.dart';
import '../widgets/recorder/recording_stats_full.dart';
import '../widgets/recorder/activity_type_selector.dart';
import 'finish_activity_screen.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  late final RecordingController _controller;
  MapLibreMapController? _mapController;
  bool _isMapExpanded = false;
  Line? _routeLine;

  @override
  void initState() {
    super.initState();
    _controller = RecordingController();
    // Listen to controller changes to update UI
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    
    // Route line should already be cleaned up before navigation
    // Just clear the reference
    _routeLine = null;
    
    super.dispose();
  }

  void _onControllerUpdate() {
    // Trigger UI rebuild when controller state changes
    setState(() {});
      
    // Only update map when card is NOT expanded to prevent plugin errors
    if (!_isMapExpanded) {
      // Update map with new GPS points when recording
      _updateMapRoute();
      
      // Update map camera position when we get new locations
      if (_mapController != null && _controller.model.positions.isNotEmpty) {
        final lastLocation = _controller.model.positions.last;        
        // Always move camera to current location when we get GPS updates
        if (_controller.model.isRecording) {
          _mapController!.moveCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(lastLocation.latitude, lastLocation.longitude),
              16.0,
            ),
          );
        }
      } else {
        log('No map controller or no positions available');
      }
    }
  }

  void _toggleMapView() {
    setState(() {
      _isMapExpanded = !_isMapExpanded;
    });
  }

  void _updateMapRoute() {
    if (_mapController == null || !_controller.model.isRecording || _isMapExpanded) return;
    
    final positions = _controller.model.positions;
    if (positions.length < 2) return; // Need at least 2 points to draw a line
    
    try {
      // Convert positions to LatLng list
      final latLngs = positions.map((pos) => 
        LatLng(pos.latitude, pos.longitude)
      ).toList();
      
      // Remove existing route line if it exists
      if (_routeLine != null) {
        _mapController!.removeLine(_routeLine!);
      }
      
      // Add new route line
      _mapController!.addLine(
        LineOptions(
          geometry: latLngs,
          lineColor: "#2196F3", // Blue color for the route TODO: it would be better to a have a contants file for colors/theme
          lineWidth: 4.0,
          lineOpacity: 0.8,
        ),
      ).then((line) {
        _routeLine = line;
      });
      
      // Center map on current position
      final lastPosition = positions.last;
      _mapController!.moveCamera(
        CameraUpdate.newLatLng(
          LatLng(lastPosition.latitude, lastPosition.longitude),
        ),
      );
    } catch (e) {
      log('Failed to update map route: $e');
    }
  }



  Future<void> _startRecording() async {
    startBackgroundService();
    // Clear any existing route line
    if (_routeLine != null && _mapController != null) {
      try {
        await _mapController!.removeLine(_routeLine!);
        _routeLine = null;
      } catch (e) {
        log('Failed to clear route line: $e');
      }
    }
    
    final success = await _controller.startRecording(context: context);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start recording. Please check location permissions.'),
        ),
      );
    }
  }

  void _pauseRecording() {
    _controller.pauseRecording();
  }

  void _resumeRecording() {
    _controller.resumeRecording();
  }

  Future<void> _finishRecording() async {
    stopBackgroundService();
    if (!_controller.hasMinimumData()) {
      // Show message if not enough data
      _showInsufficientDataDialog();
      return;
    }

    // Move to completed state
    _controller.finishRecording();
    
    // Navigate to finish activity screen
    if (mounted) {
      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (context) => FinishActivityScreen(
            formattedTime: _controller.model.formattedTime,
            formattedDistance: _controller.model.formattedDistance,
            activityName: _controller.model.activityType.displayName,
          ),
        ),
      );
      
      if (result != null && mounted) {
        if (result is Map<String, dynamic>) {
          final action = result['action'] as String?;
          
          if (action == 'discard') {
            _discardActivity();
            // Navigate back to home screen
            Navigator.pop(context);
          } else if (action == 'save') {
            // Update the model with title and description, then save
            final title = result['title'] as String?;
            final description = result['description'] as String?;
            await _saveActivity(title, description);
            // Navigate back to home screen after successful save
            Navigator.pop(context);
          } else if (action == 'resume') {
            // User wants to go back and continue recording
            // Move back to paused state so they can resume
            await _controller.resumeFromFinished();
          }
        }
      }
    }
  }

  Future<void> _cleanupRouteLine() async {
    if (_routeLine != null && _mapController != null) {
      try {
        await _mapController!.removeLine(_routeLine!);
        _routeLine = null;
        log('Route line cleaned up successfully');
      } catch (e) {
        log('Failed to cleanup route line: $e');
        // Clear the reference even if removal failed
        _routeLine = null;
      }
    }
  }

  Future<void> _saveActivity(String? title, String? description) async {
    // Clean up route line before saving and navigating away
    await _cleanupRouteLine();
    
    // Log activity details including GPS point count before resetting
    final model = _controller.model;
    log('Saving activity with details: title="$title", description="$description"');
    log('Activity data: ${model.activityType.displayName} (${model.activityType.apiName}) - ${model.formattedTime} - ${model.formattedDistance} - GPS points: ${model.positions.length}');
    
    // Save complete activity data to backend with title and description
    final activityData = _controller.getActivityData();
    if (activityData != null) {
      final model = _controller.model;
      
      // Save activity to backend with custom title and description
      final success = await ActivitiesService.instance.saveActivity(
        model, 
        title: title, 
        description: description,
      );
      
      _controller.resetToIdle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
              ? 'Activity saved successfully!' 
              : 'Failed to save activity. Please try again.'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _discardActivity() {
    _controller.resetToIdle();
  }

  Future<void> _discardRecording() async {
    stopBackgroundService();
    final shouldDiscard = await _showDiscardDialog();
    if (shouldDiscard == true) {
      _controller.discardRecording();
    }
  }



  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Activity'),
        content: const Text('Are you sure you want to discard this recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Discard'),
            ),
        ],
      ),
    );
  }

  void _showInsufficientDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insufficient Data'),
        content: const Text('Not enough GPS data collected. Please record for a longer time or distance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showActivityTypeSelector() {
    ActivityTypeSelector.show(
      context: context,
      currentType: _controller.model.activityType,
      onTypeSelected: _setActivityType,
    );
  }

  void _setActivityType(WorkoutType activityType) {
    _controller.setActivityType(activityType);
  }

  @override
  Widget build(BuildContext context) {
    final model = _controller.model;
    
    return Scaffold(
      body: Stack(
        children: [
          // Base Map Layer (Full Screen) - Hidden when card is expanded
          if (!_isMapExpanded)
            RecordingMapView(
              onMapCreated: (controller) async {
                _mapController = controller;
              },
              positions: model.positions,
            ),
          
          // Full Screen Data View when expanded
          if (_isMapExpanded)
            Container(
              color: Colors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                  child: Column(
                    children: [
                      // Collapse Button
                      Row(
                        children: [
                          const Spacer(),
                          GestureDetector(
                            onTap: _toggleMapView,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: const Icon(
                                Icons.expand_more,
                                color: Colors.black54,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Full Data View
                      Expanded(
                        child: RecordingStatsFull(
                          model: model,
                          onStart: _startRecording,
                          onPause: _pauseRecording,
                          onResume: _resumeRecording,
                          onFinish: _finishRecording,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Top Status Bar (always on top)
          SafeArea(
            child: RecordingStatusBar(
              model: model,
              onBack: () => Navigator.pop(context),
              onCenterLocation: _centerMapOnLocation,
              onDiscard: model.isCompleted ? _discardActivity : _discardRecording,
            ),
          ),
          
          // Bottom Floating Card (only when not expanded)
          if (!_isMapExpanded)
            RecordingFloatingCard(
              onTap: _toggleMapView,
              child: RecordingStatsCompact(
                model: model,
                onActivityTypeSelect: _showActivityTypeSelector,
                onStart: _startRecording,
                onPause: _pauseRecording,
                onResume: _resumeRecording,
                onFinish: _finishRecording,
              ),
            ),
        ],
      ),
    );
  }



  Future<void> _centerMapOnLocation() async {
    if (_mapController == null) return;
    
    try {
      log('Attempting to center map on current location...');
      final currentLocation = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      
      log('Got current location for centering: ${currentLocation.latitude}, ${currentLocation.longitude}');
      
      await _mapController!.moveCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(currentLocation.latitude, currentLocation.longitude),
          16.0,
        ),
      );
      
      log('Successfully centered map on current location');
    } catch (e) {
      log('Failed to center map on location: $e');
    }
  }
}

