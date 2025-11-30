/// Model for app-wide settings
class AppSettingsModel {
  // Distance unit constants
  static const String metersUnit = 'meters';
  static const String milesUnit = 'miles';
  
  // Theme mode constants  
  static const String lightTheme = 'light';
  static const String darkTheme = 'dark';
  static const String systemTheme = 'system';

  // Valid values for validation
  static const List<String> validMetricUnits = [metersUnit, milesUnit];
  static const List<String> validThemeModes = [lightTheme, darkTheme, systemTheme];

  final String metricUnit;
  final String themeMode;

  const AppSettingsModel({
    this.metricUnit = metersUnit,
    this.themeMode = lightTheme,
  });

  /// Create default settings
  factory AppSettingsModel.defaults() {
    return const AppSettingsModel();
  }

  /// Create settings with metric units (meters)
  factory AppSettingsModel.metric() {
    return const AppSettingsModel(metricUnit: metersUnit);
  }

  /// Create settings with imperial units (miles)  
  factory AppSettingsModel.imperial() {
    return const AppSettingsModel(metricUnit: milesUnit);
  }

  /// Create settings with dark theme
  factory AppSettingsModel.darkMode() {
    return const AppSettingsModel(themeMode: darkTheme);
  }

  /// Create from JSON
  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    final metricUnit = _validateMetricUnit(json['metric_unit']);
    final themeMode = _validateThemeMode(json['theme_mode']);
    
    return AppSettingsModel(
      metricUnit: metricUnit,
      themeMode: themeMode,
    );
  }

  /// Validate metric unit, return default if invalid
  static String _validateMetricUnit(dynamic value) {
    if (value is String && validMetricUnits.contains(value)) {
      return value;
    }
    return metersUnit; // default fallback
  }

  /// Validate theme mode, return default if invalid
  static String _validateThemeMode(dynamic value) {
    if (value is String && validThemeModes.contains(value)) {
      return value;
    }
    return lightTheme; // default fallback
  }

  /// Create a copy with updated values
  AppSettingsModel copyWith({
    String? metricUnit,
    String? themeMode,
  }) {
    return AppSettingsModel(
      metricUnit: metricUnit ?? this.metricUnit,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'metric_unit': metricUnit,
      'theme_mode': themeMode,
    };
  }

  /// Check if using metric units
  bool get isMetric => metricUnit == metersUnit;

  /// Check if using imperial units  
  bool get isImperial => metricUnit == milesUnit;

  /// Check if using dark theme
  bool get isDarkMode => themeMode == darkTheme;

  /// Check if using light theme
  bool get isLightMode => themeMode == lightTheme;

  /// Check if using system theme
  bool get isSystemMode => themeMode == systemTheme;

  /// Get display name for metric unit
  String get metricUnitDisplayName {
    switch (metricUnit) {
      case metersUnit:
        return 'Meters';
      case milesUnit:
        return 'Miles';
      default:
        return 'Unknown';
    }
  }

  /// Get display name for theme mode
  String get themeModeDisplayName {
    switch (themeMode) {
      case lightTheme:
        return 'Light';
      case darkTheme:
        return 'Dark';
      case systemTheme:
        return 'System';
      default:
        return 'Unknown';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettingsModel &&
        other.metricUnit == metricUnit &&
        other.themeMode == themeMode;
  }

  @override
  int get hashCode => Object.hash(metricUnit, themeMode);

  @override
  String toString() {
    return 'AppSettingsModel(metricUnit: $metricUnit, themeMode: $themeMode)';
  }
}
