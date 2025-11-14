class AppSettingsModel {
  static const String metersUnit = 'meters';
  static const String milesUnit = 'miles';
  static const String lightTheme = 'light';
  static const String darkTheme = 'dark';

  String metricUnit;
  String themeMode;

  AppSettingsModel({this.metricUnit = metersUnit, this.themeMode = lightTheme});

  AppSettingsModel copyWith({String? metricUnit, String? themeMode}) {
    return AppSettingsModel(
      metricUnit: metricUnit ?? this.metricUnit,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {'metric_unit': metricUnit, 'theme_mode': themeMode};
  }

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      metricUnit: json['metric_unit'] as String? ?? metersUnit,
      themeMode: json['theme_mode'] as String? ?? lightTheme,
    );
  }

  @override
  String toString() {
    return 'AppSettingsModel(metricUnit: $metricUnit, themeMode: $themeMode)';
  }
}
