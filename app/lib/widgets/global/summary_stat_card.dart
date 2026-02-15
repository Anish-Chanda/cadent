import 'package:flutter/material.dart';

/// A summary stat card with white background and border.
/// Used in summary screens like finish activity.
class SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? valueColor;
  final Color? labelColor;
  final double valueFontSize;
  final double labelFontSize;
  final FontWeight valueFontWeight;
  final EdgeInsets padding;

  const SummaryStatCard({
    super.key,
    required this.label,
    required this.value,
    this.backgroundColor,
    this.borderColor,
    this.valueColor,
    this.labelColor,
    this.valueFontSize = 18,
    this.labelFontSize = 14,
    this.valueFontWeight = FontWeight.bold,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? Theme.of(context).colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
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
              color: labelColor ?? Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
