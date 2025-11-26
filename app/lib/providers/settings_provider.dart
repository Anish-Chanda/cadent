import 'package:flutter/material.dart';
import 'dart:developer';

import '../services/settings_service.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService = SettingsService.instance;

  String _name = 'name';
  String get name => _name;

  Future<void> loadName() async {
    try{
      _name = await _settingsService.getName();
    }catch(e){
      log('Error loading username: $e');
    }
    notifyListeners();
  }

  Future<void> updateName(String newName) async {
    if (newName == _name) return;

    try{
      await _settingsService.saveName(newName);
    }catch(e){
      log('Error changing username: $e');
      return;
    }
    _name = newName;
    notifyListeners();
  }
}
