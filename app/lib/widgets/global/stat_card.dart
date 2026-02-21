import 'package:flutter/material.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_size.dart';

/// A stat card widget displaying a label and value.
/// Used in activity cards and summary screens.
class StatCard extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Color? valueColor;
  final Color? labelColor;
  final double iconSize;
  final double valueFontSize;
  final double labelFontSize;
  final FontWeight valueFontWeight;

  const StatCard({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.valueColor,
    this.labelColor,
    this.iconSize = AppSpacing.iconMD,
    this.valueFontSize = AppTextSize.xl,
    this.labelFontSize = AppTextSize.md,
    this.valueFontWeight = AppTextSize.bold,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: iconSize,
            color: iconColor ?? Theme.of(context).colorScheme.primary,
          ),
          AppSpacing.gapXXS,
        ],
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: valueFontWeight,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
        AppSpacing.gapXXS,
        Text(
          label,
          style: TextStyle(
            fontSize: labelFontSize,
            color: labelColor ?? Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
