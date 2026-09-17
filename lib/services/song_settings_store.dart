import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_settings.dart';

class SongSettingsStore {
  static const _prefix = 'song_settings_';

  // Colour themes used to be saved on their own, before they became one of
  // a song's settings
  static const _oldThemePrefix = 'theme_';

  static Future<SongSettings> getSettings(String songTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$songTitle');
    var settings = SongSettings.none;
    if (raw != null) {
      try {
        settings =
            SongSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }

    final oldTheme = prefs.getString('$_oldThemePrefix$songTitle');
    if (oldTheme != null) {
      settings = settings.withColorTheme(settings.colorTheme ?? oldTheme);
      await saveSettings(songTitle, settings);
      await prefs.remove('$_oldThemePrefix$songTitle');
    }
    return settings;
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
