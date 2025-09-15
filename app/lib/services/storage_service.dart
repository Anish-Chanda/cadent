import 'package:shared_preferences/shared_preferences.dart';

const _kServerUrlKey = 'cadence_server_url';

class StorageService {
  static Future<SharedPreferences> _prefs() async =>
      await SharedPreferences.getInstance();

  // Save the server URL for future app launches.
  static Future<void> saveServerUrl(String url) async {
    final prefs = await _prefs();
    await prefs.setString(_kServerUrlKey, url);
  }

  // Read the persisted server URL (or null if none was saved).
  static Future<String?> getServerUrl() async {
    final prefs = await _prefs();
    return prefs.getString(_kServerUrlKey);
  }
}
