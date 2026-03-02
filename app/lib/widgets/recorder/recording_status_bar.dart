import 'package:flutter/material.dart';
import '../../models/recording_session_model.dart';
import '../../utils/app_spacing.dart';

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
      padding: AppSpacing.paddingMD,
      child: Row(
        children: [
          // Back Button
          Container(
            width: AppSpacing.xxxl,
            height: AppSpacing.xxxl,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color, size: AppSpacing.iconSM),
              onPressed: onBack,
              padding: EdgeInsets.zero,
            ),
          ),

          const Spacer(),

          const Spacer(),

          // Center Map Button
          Container(
            width: AppSpacing.xxxl,
            height: AppSpacing.xxxl,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            ),
            child: IconButton(
              onPressed: onCenterLocation,
              icon: Icon(
                Icons.my_location,
                color: Theme.of(context).colorScheme.primary,
                size: AppSpacing.iconSM,
              ),
              padding: EdgeInsets.zero,
            ),
          ),

          // Discard Button
          if (model.isActive || model.isCompleted)
            Container(
              margin: EdgeInsets.only(left: AppSpacing.xs),
              width: AppSpacing.xxxl,
              height: AppSpacing.xxxl,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
              ),
              child: IconButton(
                icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error, size: AppSpacing.iconSM),
                onPressed: onDiscard,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}
