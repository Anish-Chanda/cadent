
import 'package:flutter/material.dart';
import 'app_spacing.dart';
import 'app_text_size.dart';
import 'app_colors.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primaryBlue,
    ),
    primaryColor: AppColors.primaryBlue,
    useMaterial3: true,
    
    // Text field styling
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: AppSpacing.paddingMD,
      border: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      hintStyle: TextStyle(
        fontSize: AppTextSize.md,
        color: Colors.grey.shade500,
      ),
      labelStyle: const TextStyle(
        fontSize: AppTextSize.md,
        fontWeight: AppTextSize.medium,
      ),
    ),
    
    // Elevated button styling
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, AppSpacing.huge),
        padding: AppSpacing.paddingHorizontalXL,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusFull,
        ),
        textStyle: const TextStyle(
          fontSize: AppTextSize.lg,
          fontWeight: AppTextSize.semiBold,
        ),
        elevation: AppSpacing.elevationXS,
      ),
    ),
    
    // Text button styling
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: AppSpacing.paddingMD,
        textStyle: const TextStyle(
          fontSize: AppTextSize.lg,
          fontWeight: AppTextSize.medium,
        ),
      ),
    ),
    
    // Outlined button styling
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        minimumSize: Size(double.infinity, AppSpacing.huge),
        padding: AppSpacing.paddingHorizontalXL,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusFull,
        ),
        textStyle: const TextStyle(
          fontSize: AppTextSize.lg,
          fontWeight: AppTextSize.semiBold,
        ),
        side: const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryBlue,
    ),
    primaryColor: AppColors.primaryBlue,
    useMaterial3: true,
    
    // Text field styling for dark mode
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade900,
      contentPadding: AppSpacing.paddingMD,
      border: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMD,
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      hintStyle: TextStyle(
        fontSize: AppTextSize.md,
        color: Colors.grey.shade600,
      ),
      labelStyle: const TextStyle(
        fontSize: AppTextSize.md,
        fontWeight: AppTextSize.medium,
      ),
    ),
    
    // Elevated button styling for dark mode
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, AppSpacing.huge),
        padding: AppSpacing.paddingHorizontalXL,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusFull,
        ),
        textStyle: const TextStyle(
          fontSize: AppTextSize.lg,
          fontWeight: AppTextSize.semiBold,
        ),
        elevation: AppSpacing.elevationXS,
      ),
    ),
    
    // Text button styling for dark mode
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: AppSpacing.paddingMD,
        textStyle: const TextStyle(
          fontSize: AppTextSize.lg,
          fontWeight: AppTextSize.medium,
        ),
      ),
    ),
    
    // Outlined button styling for dark mode
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        minimumSize: Size(double.infinity, AppSpacing.huge),
        padding: AppSpacing.paddingHorizontalXL,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusFull,
        ),
        textStyle: const TextStyle(
          fontSize: AppTextSize.lg,
          fontWeight: AppTextSize.semiBold,
        ),
        side: const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
    ),
  );
  
  // Helper to get map style based on theme
  static String getMapStyle(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? 'https://tiles.openfreemap.org/styles/dark'
        : 'https://tiles.openfreemap.org/styles/liberty';
  }
}