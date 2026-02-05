import 'package:flutter/material.dart';
import '../../models/recording_session_model.dart';
import '../global/compact_stat.dart';

/// Compact recording stats view shown in the bottom floating card.
/// Displays time, distance, speed, and control buttons.
class RecordingStatsCompact extends StatelessWidget {
  final RecordingSessionModel model;
  final VoidCallback? onActivityTypeSelect;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onFinish;

  const RecordingStatsCompact({
    super.key,
    required this.model,
    this.onActivityTypeSelect,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Activity Type Selector (only when idle)
          if (model.isIdle) ...[
            GestureDetector(
              onTap: onActivityTypeSelect,
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
                      onTap: model.isRecording ? onPause : onResume,
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
                      onTap: onFinish,
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
                      onTap: onStart,
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
                  child: CompactStat(
                    value: model.formattedDistance,
                    label: 'Distance',
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: CompactStat(
                    value: model.isRecording ? model.formattedSpeed : '--',
                    label: 'Speed',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

