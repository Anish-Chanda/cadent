import 'package:flutter/material.dart';
import '../../models/recording_session_model.dart';

/// Control button widget for recorder screen (pause/resume).
class RecordingControlButton extends StatelessWidget {
  final RecordingSessionModel model;
  final VoidCallback onPause;
  final VoidCallback onResume;

  const RecordingControlButton({
    super.key,
    required this.model,
    required this.onPause,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    if (!model.isRecording && !model.isPaused) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        if (model.isRecording) {
          onPause();
        } else if (model.isPaused) {
          onResume();
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: model.isRecording ? theme.colorScheme.error : theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          model.isRecording ? Icons.pause : Icons.play_arrow,
          color: model.isRecording ? theme.colorScheme.onError : theme.colorScheme.onPrimary,
          size: 20,
        ),
      ),
    );
  }
}
