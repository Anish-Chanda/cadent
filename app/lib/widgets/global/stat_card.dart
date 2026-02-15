import 'package:flutter/material.dart';

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
    this.iconSize = 24,
    this.valueFontSize = 18,
    this.labelFontSize = 14,
    this.valueFontWeight = FontWeight.bold,
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
          const SizedBox(height: 4),
        ],
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: valueFontWeight,
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
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
