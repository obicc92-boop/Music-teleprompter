import 'dart:io';

/// Whether two paths name the same file. Songs saved over time carry both
/// `scripts/Song.txt` and `scripts\Song.txt`, and Windows doesn't mind case.
bool samePath(String a, String b) {
  if (a == b) return true;
  var x = a.replaceAll(r'\', '/');
  var y = b.replaceAll(r'\', '/');
  if (Platform.isWindows) {
    x = x.toLowerCase();
    y = y.toLowerCase();
  }
  return x == y;
}
