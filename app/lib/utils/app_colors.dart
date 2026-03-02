import 'package:flutter/material.dart';

/// Defines app-specific color constants for consistent branding and theming.
/// Use these instead of hardcoded hex values throughout the app.
class AppColors {
  AppColors._();

  // Brand colors
  static const Color primaryBlue = Color(0xFF59c4f7);
  
  // Gradient colors (used in buttons, backgrounds)
  static const Color gradientGreenStart = Color(0xFF4CAF50);
  static const Color gradientGreenEnd = Color(0xFF45a049);
  
  // Semantic colors (can be extended as needed)
  // These complement the theme's ColorScheme but provide app-specific colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFF44336);
  static const Color infoBlue = Color(0xFF2196F3);
}
