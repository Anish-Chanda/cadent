import 'dart:developer';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../controllers/recording_controller.dart';
import '../models/recording_session_model.dart';
import '../services/activities_service.dart';
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
    } else {
      log('Map updates skipped - card is expanded');
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
    showModalBottomSheet<WorkoutType>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Activity Type',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            ...WorkoutType.values.map((type) => 
              ListTile(
                title: Text(
                  type.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: _controller.model.activityType == type 
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
                onTap: () {
                  _setActivityType(type);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
          if (!_isMapExpanded) _buildMapLayer(),
          
          // Full Screen Data View when expanded
          if (_isMapExpanded) _buildFullScreenDataView(model),
          
          // Top Status Bar (always on top)
          SafeArea(child: _buildTopStatusBar(model)),
          
          // Location Button moved to top status bar
          
          // Bottom Floating Card (only when not expanded)
          if (!_isMapExpanded) _buildBottomFloatingCard(model),
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

  Widget _buildMapLayer() {
    // TODO: replace with our basemap server
    return MapLibreMap(
      styleString: 'https://tiles.openfreemap.org/styles/liberty',
      initialCameraPosition: const CameraPosition(
        target: LatLng(37.7749, -122.4194), // Default to San Francisco
        zoom: 14.0,
      ),
      myLocationEnabled: true,
      myLocationTrackingMode: MyLocationTrackingMode.tracking,
      myLocationRenderMode: MyLocationRenderMode.normal,
      onMapCreated: (MapLibreMapController controller) async {
        _mapController = controller;
        log('Map controller created');
        
        // Try to get current location first
        try {
          final currentLocation = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10), // Increased timeout
            ),
          );          
          // Move camera to current location
          await controller.moveCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(currentLocation.latitude, currentLocation.longitude),
              16.0,
            ),
          );
        } catch (e) {
          log('Failed to get current location: $e');
          
          // Fallback to recorded positions if available
          if (_controller.model.positions.isNotEmpty) {
            final lastLocation = _controller.model.positions.last;
            log('Using last recorded position: ${lastLocation.latitude}, ${lastLocation.longitude}');
            await controller.moveCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(lastLocation.latitude, lastLocation.longitude),
                16.0,
              ),
            );
          } else {
            log('No recorded positions available, staying at default location');
          }
        }
      },
    );
  }

  Widget _buildBottomFloatingCard(RecordingSessionModel model) {
    return Positioned(
      bottom: 30,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: _toggleMapView,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              
              // Data Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _buildCompactDataView(model),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenDataView(RecordingSessionModel model) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 20), // Top padding for status bar
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
                child: _buildFullDataView(model),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopStatusBar(RecordingSessionModel model) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back Button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
            ),
          ),
          
          const Spacer(),
          
          const Spacer(),
          
          // Center Map Button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: _centerMapOnLocation,
              icon: const Icon(
                Icons.my_location,
                color: Colors.blue,
                size: 20,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
          
          // Actions Menu
          if (model.isActive || model.isCompleted)
            Container(
              margin: const EdgeInsets.only(left: 8),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: model.isCompleted ? _discardActivity : _discardRecording,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }



  Widget _buildCompactDataView(RecordingSessionModel model) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Activity Type Selector (only when idle)
          if (model.isIdle) ...[
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showActivityTypeSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Text(
                            model.activityType.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Top row: Time (left) and Control buttons (right)
          Row(
            children: [
              // Time section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Time',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model.formattedTime,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Control buttons based on state
              Row(
                children: [
                  // Pause/Resume Button - show when recording or paused
                  if (model.isRecording || model.isPaused)
                    GestureDetector(
                      onTap: () {
                        if (model.isRecording) {
                          _pauseRecording();
                        } else if (model.isPaused) {
                          _resumeRecording();
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: model.isRecording ? Colors.orange : Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          model.isRecording ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                  // Finish Button - show when recording or paused
                  if (model.isRecording || model.isPaused) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _finishRecording,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.stop,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],

                  // Start Recording button when idle
                  if (model.isIdle)
                    GestureDetector(
                      onTap: _startRecording,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Text(
                          'Start',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Bottom row: Stats (Distance and Speed)
          if (model.isActive || model.isCompleted) 
            Row(
              children: [
                Expanded(
                  child: _buildCompactStat(model.formattedDistance, 'Distance'),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildCompactStat(
                    model.isRecording ? model.formattedSpeed : '--',
                    'Speed'
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFullDataView(RecordingSessionModel model) {
    return Column(
      children: [
        // Recording Status Indicator
        if (model.isActive) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: model.isRecording ? Colors.red : Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  model.isRecording ? Icons.fiber_manual_record : Icons.pause,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  model.isRecording ? 'RECORDING' : 'PAUSED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],

        // Time Display
        Text(
          model.formattedTime,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 56,
            fontWeight: FontWeight.w300,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          'Running Time',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 32),

        // Distance Display
        Text(
          model.formattedDistance,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 40,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          'Distance',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        // Speed Display (only show when recording)
        if (model.isRecording) ...[
          Text(
            model.formattedSpeed,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 32,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            'Current Speed',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
        ],

        const Spacer(),

        // Control Buttons
        _buildControlButtons(model),
      ],
    );
  }

  Widget _buildCompactStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons(RecordingSessionModel model) {
    if (model.isIdle) {
      return Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: ElevatedButton(
          onPressed: _startRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text(
            'Start Recording',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (model.isRecording) {
      return Row(
        children: [
          Expanded(
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(30),
              ),
              child: ElevatedButton(
                onPressed: _pauseRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Pause',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(30),
              ),
              child: ElevatedButton(
                onPressed: _finishRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Finish',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (model.isPaused) {
      return Row(
        children: [
          Expanded(
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: ElevatedButton(
                onPressed: _resumeRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Resume',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(30),
              ),
              child: ElevatedButton(
                onPressed: _finishRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Finish',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (model.isCompleted) {
      // Activity is completed - user should use finish screen to save
      // This state shouldn't be visible as finish screen is immediately pushed
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Text(
          'Activity completed. Use the finish screen to save or continue recording.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
