import 'package:flutter/material.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_size.dart';

/// An empty state widget displaying an icon, title, and optional message.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final double iconSize;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.iconSize = AppSpacing.massive,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          AppSpacing.gapMD,
          Text(
            title,
            style: AppTextStyles.headlineSmall(
              context,
              fontWeight: AppTextSize.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (message != null) ...[
            AppSpacing.gapXS,
            Padding(
              padding: AppSpacing.paddingHorizontalXXL,
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium(
                  context,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
