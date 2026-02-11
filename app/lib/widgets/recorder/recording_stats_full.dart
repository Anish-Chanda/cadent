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
              color: model.isRecording ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  model.isRecording ? Icons.fiber_manual_record : Icons.pause,
                  color: Theme.of(context).colorScheme.onError,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  model.isRecording ? 'RECORDING' : 'PAUSED',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onError),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],

        // Time Display
        Text(
          model.formattedTime,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w300, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        Text(
          'Running Time',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 32),

        // Distance Display
        Text(
          model.formattedDistance,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w400),
        ),
        Text(
          'Distance',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 24),

        // Speed Display (only show when recording)
        if (model.isRecording) ...[
          Text(
            model.formattedSpeed,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w400),
          ),
          Text(
            'Current Speed',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
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
