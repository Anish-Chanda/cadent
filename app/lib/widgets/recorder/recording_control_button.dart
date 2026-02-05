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
          color: model.isRecording ? Colors.orange : Colors.blue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          model.isRecording ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
