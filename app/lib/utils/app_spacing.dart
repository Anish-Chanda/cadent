import 'package:flutter/material.dart';

/// Defines consistent spacing values throughout the app.
/// Based on 8pt grid system
class AppSpacing {
  AppSpacing._();

  // Base spacing values
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 48.0;
  static const double massive = 64.0;

  // Common EdgeInsets presets
  static const EdgeInsets paddingSM = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD = EdgeInsets.all(md);

  // Horizontal padding presets
  static const EdgeInsets paddingHorizontalMD = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalXL = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets paddingHorizontalXXL = EdgeInsets.symmetric(horizontal: xxl);

  // Vertical padding presets
  static const EdgeInsets paddingVerticalXS = EdgeInsets.symmetric(vertical: xs);

  // Common SizedBox presets (Vertical gaps)
  static const SizedBox gapXXS = SizedBox(height: xxs);
  static const SizedBox gapXS = SizedBox(height: xs);
  static const SizedBox gapSM = SizedBox(height: sm);
  static const SizedBox gapMD = SizedBox(height: md);
  static const SizedBox gapLG = SizedBox(height: lg);
  static const SizedBox gapXL = SizedBox(height: xl);
  static const SizedBox gapXXL = SizedBox(height: xxl);
  static const SizedBox gapXXXL = SizedBox(height: xxxl);
  static const SizedBox gapHuge = SizedBox(height: huge);

  // Common SizedBox presets (Horizontal gaps)
  static const SizedBox gapHorizontalXXS = SizedBox(width: xxs);
  static const SizedBox gapHorizontalXS = SizedBox(width: xs);
  static const SizedBox gapHorizontalSM = SizedBox(width: sm);
  static const SizedBox gapHorizontalMD = SizedBox(width: md);
  static const SizedBox gapHorizontalLG = SizedBox(width: lg);

  // Border radius values
  static const double radiusXS = 4.0;
  static const double radiusMD = 12.0;
  static const double radiusXL = 20.0;
  static const double radiusFull = 999.0; // For fully rounded elements

  // Common BorderRadius presets
  static final BorderRadius borderRadiusMD = BorderRadius.circular(radiusMD);
  static final BorderRadius borderRadiusFull = BorderRadius.circular(radiusFull);

  // Icon sizes
  static const double iconXS = 16.0;
  static const double iconSM = 20.0;
  static const double iconMD = 24.0;
  static const double iconLG = 28.0;

  // Common elevation values
  static const double elevationXS = 1.0;
}