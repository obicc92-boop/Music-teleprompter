import 'package:shared_preferences/shared_preferences.dart';

class SongAudioStore {
  static const _prefix = 'audio_path_';

  static Future<String?> getPath(String songTitle) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$songTitle');
  }

  static Future<void> savePath(String songTitle, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$songTitle', path);
  }

  static Future<void> removePath(String songTitle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$songTitle');
  }
}
