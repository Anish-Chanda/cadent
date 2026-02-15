import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../../models/recording_session_model.dart';
import 'recording_control_panel.dart';

/// Full-screen stats view shown when the card is expanded.
/// Displays time, distance, speed, and control buttons in a large format.
class RecordingStatsFull extends StatelessWidget {
  final RecordingSessionModel model;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onFinish;

  const RecordingStatsFull({
    super.key,
    required this.model,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
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
        RecordingControlPanel(
          model: model,
          onStart: onStart,
          onPause: onPause,
          onResume: onResume,
          onFinish: onFinish,
        ),
      ],
    );
  }
}
