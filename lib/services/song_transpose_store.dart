import 'package:shared_preferences/shared_preferences.dart';

class SongTransposeStore {
  static const _prefix = 'transpose_';

  static Future<int> getTranspose(String songTitle) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$songTitle') ?? 0;
  }

  static Future<void> saveTranspose(String songTitle, int semitones) async {
    final prefs = await SharedPreferences.getInstance();
    final s = ((semitones % 12) + 12) % 12;
    if (s == 0) {
      await prefs.remove('$_prefix$songTitle');
    } else {
      await prefs.setInt('$_prefix$songTitle', s);
    }
  }
}
