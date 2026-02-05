import 'package:flutter/material.dart';

/// A text button styled as a link with consistent styling across the app.
/// Use this for inline links and secondary navigation.
class TextLinkButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final double fontSize;
  final FontWeight fontWeight;

  const TextLinkButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.fontSize = 14,
    this.fontWeight = FontWeight.normal,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
          color: color ?? Theme.of(context).primaryColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}
