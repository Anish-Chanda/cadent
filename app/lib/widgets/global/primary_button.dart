import 'package:flutter/material.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_text_size.dart';
import '../../utils/app_colors.dart';

/// A customizable primary button widget with consistent styling across the app.
/// Use this for main action buttons.
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? height;
  final double? width;
  final Color? backgroundColor;
  final Color? textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsets? padding;
  final bool hasGradient;
  final List<Color>? gradientColors;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.height = AppSpacing.huge,
    this.width,
    this.backgroundColor,
    this.textColor,
    this.fontSize = AppTextSize.lg,
    this.fontWeight = AppTextSize.semiBold,
    this.padding,
    this.hasGradient = false,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? double.infinity;
    final effectiveBackgroundColor = backgroundColor ?? Theme.of(context).colorScheme.primary;
    final effectiveTextColor = textColor ?? Theme.of(context).colorScheme.onPrimary;

    Widget button = SizedBox(
      width: effectiveWidth,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: hasGradient ? Colors.transparent : effectiveBackgroundColor,
          shadowColor: hasGradient ? Colors.transparent : null,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusFull,
          ),
          padding: padding,
        ),
        child: isLoading
            ? SizedBox(
                height: AppSpacing.iconSM,
                width: AppSpacing.iconSM,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(effectiveTextColor),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: effectiveTextColor,
                ),
              ),
      ),
    );

    if (hasGradient) {
      return Container(
        width: effectiveWidth,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors ?? [AppColors.gradientGreenStart, AppColors.gradientGreenEnd],
          ),
          borderRadius: AppSpacing.borderRadiusFull,
        ),
        child: button,
      );
    }

    return button;
  }
}
