import 'package:flutter/material.dart';
import '../../utils/app_spacing.dart';

/// Floating card wrapper with drag handle.
/// Used to contain recording stats in a draggable bottom card.
class RecordingFloatingCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const RecordingFloatingCard({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: AppSpacing.xxxl,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.2),
                blurRadius: AppSpacing.xl,
                offset: const Offset(0, AppSpacing.xs),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                padding: AppSpacing.paddingSM,
                child: Center(
                  child: Container(
                    width: AppSpacing.xxxl,
                    height: AppSpacing.xxs,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
