import 'package:flutter/material.dart';

import '../controllers/recording_controller.dart';
import '../models/recording_session_model.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  late final RecordingController _controller;

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
    super.dispose();
  }

  void _onControllerUpdate() {
    // Trigger UI rebuild when controller state changes
    setState(() {});
  }

  Future<void> _startRecording() async {
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
  }

  Future<void> _saveActivity() async {
    final activityData = _controller.getActivityData();
    if (activityData != null) {
      // TODO: Implement saving activity to backend via ActivitiesService
      _controller.resetToIdle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity saved!')),
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

  @override
  Widget build(BuildContext context) {
    final model = _controller.model;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Recorder'),
        actions: [
          if (model.isActive)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _discardRecording,
              tooltip: 'Discard Recording',
            ),
          if (model.isCompleted)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _discardActivity,
              tooltip: 'Discard Activity',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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

            // Completed Status Indicator
            if (model.isCompleted) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'COMPLETED',
                      style: TextStyle(
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
                fontSize: 56,
                fontWeight: FontWeight.w300,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const Text(
              'Time',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),

            // Distance Display
            Text(
              model.formattedDistance,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Text(
              'Distance',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            // Speed Display (only show when recording)
            if (model.isRecording) ...[
              Text(
                model.formattedSpeed,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Text(
                'Current Speed',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
            ] else
              const SizedBox(height: 32),

            // Control Buttons
            _buildControlButtons(model),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(RecordingSessionModel model) {
    if (model.isIdle) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _startRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Start Recording',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    if (model.isRecording) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _pauseRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Pause', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _finishRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Finish', style: TextStyle(fontSize: 16)),
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
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _resumeRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Resume', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _finishRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Finish', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      );
    }

    if (model.isCompleted) {
      return Column(
        children: [
          // Activity summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Distance: ${model.formattedDistance}\n'
              'Time: ${model.formattedTime}\n'
              'GPS Points: ${model.pointsCount}',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _discardActivity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Discard', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveActivity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
