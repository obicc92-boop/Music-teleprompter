import 'package:shared_preferences/shared_preferences.dart';

class SongLrcContentStore {
  static String _key(String title) =>
      'lrc_content_${title.toLowerCase().replaceAll(' ', '_')}';

  static Future<String?> getContent(String title) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(title));
  }

  static Future<void> saveContent(String title, String content) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(title), content);
  }

  static Future<void> removeContent(String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(title));
  }
}
