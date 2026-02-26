import 'package:flutter/material.dart';
import '../../models/recording_session_model.dart';
import '../../utils/app_spacing.dart';
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
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Text(
                      model.activityType.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.gapSM,
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
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model.formattedTime,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
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
                          color: model.isRecording
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          model.isRecording ? Icons.pause : Icons.play_arrow,
                          color: model.isRecording
                              ? Theme.of(context).colorScheme.onSecondary
                              : Theme.of(context).colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                    ),

                  // Finish Button - show when recording or paused
                  if (model.isRecording || model.isPaused) ...[
                    AppSpacing.gapHorizontalXS,
                    GestureDetector(
                      onTap: onFinish,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.stop,
                          color: Theme.of(context).colorScheme.onError,
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
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            'Start',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
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

          AppSpacing.gapMD,

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
                AppSpacing.gapHorizontalLG,
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

