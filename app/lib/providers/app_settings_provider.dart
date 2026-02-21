import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/app_settings.dart';

class AppSettingsProvider extends ChangeNotifier {
  AppSettingsModel _settings = AppSettingsModel.defaults();
  static const String _storageKey = 'app_settings';

  AppSettingsModel get settings => _settings;
  String get metricUnit => _settings.metricUnit;
  String get themeMode => _settings.themeMode;
  
  // Convenience getters using model features
  bool get isMetric => _settings.isMetric;
  bool get isImperial => _settings.isImperial;
  bool get isDarkMode => _settings.isDarkMode;
  bool get isLightMode => _settings.isLightMode;
  String get metricUnitDisplayName => _settings.metricUnitDisplayName;
  String get themeModeDisplayName => _settings.themeModeDisplayName;

  AppSettingsProvider() {
    _loadSettings();
  }

  // Load settings from persistent storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? settingsJson = prefs.getString(_storageKey);

      if (settingsJson != null) {
        final Map<String, dynamic> settingsMap = json.decode(settingsJson);
        _settings = AppSettingsModel.fromJson(settingsMap);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // Save settings to persistent storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String settingsJson = json.encode(_settings.toJson());
      await prefs.setString(_storageKey, settingsJson);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  // Update metric unit
  Future<void> setMetricUnit(String unit) async {
    if (_settings.metricUnit != unit) {
      _settings = _settings.copyWith(metricUnit: unit);
      notifyListeners();
      await _saveSettings();
    }
  }

  // Update theme mode
  Future<void> setThemeMode(String mode) async {
    if (_settings.themeMode != mode) {
      _settings = _settings.copyWith(themeMode: mode);
      notifyListeners();
      await _saveSettings();
    }
  }

  // Toggle theme mode
  Future<void> toggleThemeMode() async {
    final newMode = _settings.themeMode == AppSettingsModel.lightTheme
        ? AppSettingsModel.darkTheme
        : AppSettingsModel.lightTheme;
    await setThemeMode(newMode);
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    _settings = AppSettingsModel.defaults();
    notifyListeners();
    await _saveSettings();
  }
}
