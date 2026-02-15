import 'package:flutter/material.dart';

/// A compact stat display widget showing label and value.
/// Used for displaying stats in a more condensed format.
class CompactStat extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final Color? labelColor;
  final double valueFontSize;
  final double labelFontSize;
  final FontWeight valueFontWeight;

  const CompactStat({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.labelColor,
    this.valueFontSize = 16,
    this.labelFontSize = 12,
    this.valueFontWeight = FontWeight.bold,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor ?? Theme.of(context).colorScheme.outline,
            fontSize: labelFontSize,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            fontSize: valueFontSize,
            fontWeight: valueFontWeight,
          ),
        ),
      ],
    );
  }
}
