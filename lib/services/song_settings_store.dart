import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_settings.dart';

class SongSettingsStore {
  static const _prefix = 'song_settings_';

  static Future<SongSettings> getSettings(String songTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$songTitle');
    if (raw == null) return SongSettings.none;
    try {
      return SongSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return SongSettings.none;
    }
  }

  static Future<void> saveSettings(
      String songTitle, SongSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings.isEmpty) {
      await prefs.remove('$_prefix$songTitle');
    } else {
      await prefs.setString(
          '$_prefix$songTitle', jsonEncode(settings.toJson()));
    }
  }
}
