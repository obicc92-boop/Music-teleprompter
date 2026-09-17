import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_theme.dart';

class SongThemeStore {
  static const _prefix = 'theme_';

  static Future<SongTheme> getTheme(String songTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('$_prefix$songTitle');
    return id != null ? SongTheme.fromId(id) : SongTheme.defaultTheme;
  }

  static Future<void> saveTheme(String songTitle, SongTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    if (theme.id == SongTheme.defaultTheme.id) {
      await prefs.remove('$_prefix$songTitle');
    } else {
      await prefs.setString('$_prefix$songTitle', theme.id);
    }
  }
}
