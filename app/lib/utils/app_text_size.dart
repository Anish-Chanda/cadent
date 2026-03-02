import 'package:flutter/material.dart';

/// Defines consistent typography and text sizing values throughout the app.
/// Follows Material 3 Design typography scale with semantic naming.
class AppTextSize {
  AppTextSize._();

  // Font sizes (Material 3 scale - only commonly used sizes)
  static const double xs = 10.0;  // Small labels, captions
  static const double sm = 12.0;  // Labels, secondary text
  static const double md = 14.0;  // Body text, labels
  static const double lg = 16.0;  // Body text, buttons
  static const double xl = 18.0;  // Titles, stats
  static const double xxl = 22.0; // Section headers
  static const double xxxl = 24.0; // Large titles
  static const double huge = 32.0; // Headlines
  static const double mega = 48.0; // Display text

  // Font weights
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // Letter spacing
  static const double letterSpacingWide = 0.5;
}

/// Provides semantic text style helpers that integrate with theme.
/// Use these instead of hardcoding TextStyles for consistency.
class AppTextStyles {
  AppTextStyles._();

  // Display styles (largest text)
  static TextStyle display(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return Theme.of(context).textTheme.displayLarge?.copyWith(
          fontWeight: fontWeight,
          color: color,
          height: height,
        ) ??
        TextStyle(
          fontSize: AppTextSize.mega,
          fontWeight: fontWeight ?? AppTextSize.light,
          color: color,
          height: height,
        );
  }

  // Headline styles
  static TextStyle headlineLarge(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontWeight: fontWeight,
          color: color,
        ) ??
        TextStyle(
          fontSize: AppTextSize.huge,
          fontWeight: fontWeight ?? AppTextSize.regular,
          color: color,
        );
  }

  static TextStyle headlineMedium(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: fontWeight,
          color: color,
        ) ??
        TextStyle(
          fontSize: AppTextSize.xxxl,
          fontWeight: fontWeight ?? AppTextSize.regular,
          color: color,
        );
  }

  static TextStyle headlineSmall(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: fontWeight,
          color: color,
        ) ??
        TextStyle(
          fontSize: AppTextSize.xxl,
          fontWeight: fontWeight ?? AppTextSize.regular,
          color: color,
        );
  }

  // Title styles
  static TextStyle titleLarge(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: fontWeight,
          color: color,
        ) ??
        TextStyle(
          fontSize: AppTextSize.xl,
          fontWeight: fontWeight ?? AppTextSize.medium,
          color: color,
        );
  }

  static TextStyle titleMedium(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: fontWeight,
          color: color,
        ) ??
        TextStyle(
          fontSize: AppTextSize.lg,
          fontWeight: fontWeight ?? AppTextSize.medium,
          color: color,
        );
  }

  static TextStyle titleSmall(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: fontWeight,
          color: color,
        ) ??
        TextStyle(
          fontSize: AppTextSize.md,
          fontWeight: fontWeight ?? AppTextSize.medium,
          color: color,
        );
  }

  // Body styles
  static TextStyle bodyLarge(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: fontWeight,
          color: color,
        ) ??
        TextStyle(
          fontSize: AppTextSize.lg,
          fontWeight: fontWeight ?? AppTextSize.regular,
          color: color,
        );
  }

  static TextStyle bodyMedium(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: fontWeight,
          color: color,
        ) ??
        TextStyle(
          fontSize: AppTextSize.md,
          fontWeight: fontWeight ?? AppTextSize.regular,
          color: color,
        );
  }

  static TextStyle bodySmall(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: fontWeight,
          color: color,
        ) ??
        TextStyle(
          fontSize: AppTextSize.sm,
          fontWeight: fontWeight ?? AppTextSize.regular,
          color: color,
        );
  }

  // Label styles (for buttons, chips, etc.)
  static TextStyle labelLarge(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: fontWeight,
          color: color,
        ) ??
        TextStyle(
          fontSize: AppTextSize.md,
          fontWeight: fontWeight ?? AppTextSize.medium,
          color: color,
          letterSpacing: AppTextSize.letterSpacingWide,
        );
  }

  static TextStyle labelMedium(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: fontWeight,
          color: color,
        ) ??
        TextStyle(
          fontSize: AppTextSize.sm,
          fontWeight: fontWeight ?? AppTextSize.medium,
          color: color,
          letterSpacing: AppTextSize.letterSpacingWide,
        );
  }

  static TextStyle labelSmall(
    BuildContext context, {
    FontWeight? fontWeight,
    Color? color,
  }) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: fontWeight,
          color: color,
        ) ??
        TextStyle(
          fontSize: AppTextSize.xs,
          fontWeight: fontWeight ?? AppTextSize.medium,
          color: color,
          letterSpacing: AppTextSize.letterSpacingWide,
        );
  }
}

