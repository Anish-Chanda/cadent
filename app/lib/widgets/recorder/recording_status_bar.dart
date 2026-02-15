import 'package:flutter/material.dart';
import '../../models/recording_session_model.dart';

/// Top status bar for the recorder screen.
/// Shows back button, center location button, and discard button.
class RecordingStatusBar extends StatelessWidget {
  final RecordingSessionModel model;
  final VoidCallback? onBack;
  final VoidCallback? onCenterLocation;
  final VoidCallback? onDiscard;

  const RecordingStatusBar({
    super.key,
    required this.model,
    this.onBack,
    this.onCenterLocation,
    this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
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
              onPressed: onBack,
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
              onPressed: onCenterLocation,
              icon: const Icon(
                Icons.my_location,
                color: Colors.blue,
                size: 20,
              ),
              padding: EdgeInsets.zero,
            ),
          ),

          // Discard Button
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
                onPressed: onDiscard,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}
