import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/setlist_models.dart';
import '../utils/constants.dart';
import 'song_settings_store.dart';

class SetlistExportService {
  /// Writes a print-ready HTML file to Downloads and opens it in the browser.
  /// Returns the path on success, null on failure.
  static Future<String?> exportHtml(Setlist setlist) async {
    try {
      final dir = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final safeName =
          setlist.name.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
      final fileName =
          '${safeName.isEmpty ? 'Setlist' : safeName}_${DateTime.now().millisecondsSinceEpoch}.html';
      final file = File('${dir.path}/$fileName');
      final songSpeeds = <String, double?>{
        for (final item in setlist.items.where((i) => i.isSong))
          item.title:
              (await SongSettingsStore.getSettings(item.title)).scrollSpeedMultiplier,
      };
      await file.writeAsString(_buildHtml(setlist, songSpeeds));
      await _openFile(file.path);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static String _buildHtml(Setlist setlist, Map<String, double?> songSpeeds) {
    final songRows = StringBuffer();
    int songNumber = 0;
    for (final item in setlist.items) {
      if (item.isSeparator) {
        songRows.write('''
          <tr class="sep"><td colspan="3">${_esc(item.text)}</td></tr>
        ''');
      } else {
        songNumber++;
        final songSpeed = songSpeeds[item.title];
        final speed =
            songSpeed != null ? ScrollConstants.speedLabel(songSpeed) : '—';
        final hex = '#${(item.colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
        songRows.write('''
          <tr>
            <td class="num">$songNumber</td>
            <td class="title">
              <span class="dot" style="background:$hex"></span>
              ${_esc(item.title)}
            </td>
            <td class="meta">${_esc(item.note)}<span class="speed">$speed</span></td>
          </tr>
        ''');
      }
    }

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>${_esc(setlist.name)}</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap');
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Inter', -apple-system, sans-serif; background: #fff; color: #111; padding: 40px 48px; max-width: 760px; margin: 0 auto; }
  h1 { font-size: 28px; font-weight: 700; margin-bottom: 4px; }
  .date { font-size: 13px; color: #888; margin-bottom: 32px; letter-spacing: 0.5px; }
  table { width: 100%; border-collapse: collapse; }
  tr { border-bottom: 1px solid #eee; }
  tr:last-child { border-bottom: none; }
  td { padding: 12px 8px; vertical-align: middle; }
  .num { width: 36px; font-size: 12px; color: #bbb; font-weight: 600; text-align: right; padding-right: 16px; }
  .title { font-size: 16px; font-weight: 600; display: flex; align-items: center; gap: 10px; }
  .dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
  .meta { font-size: 12px; color: #888; text-align: right; white-space: nowrap; }
  .speed { display: inline-block; margin-left: 10px; background: #f3f3f3; padding: 2px 7px; border-radius: 4px; font-size: 11px; }
  tr.sep td { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 2px; color: #aaa; padding: 20px 8px 8px; border-bottom: none; }
  @media print { body { padding: 0; } }
</style>
</head>
<body>
<h1>${_esc(setlist.name)}</h1>
<p class="date">$dateStr &nbsp;·&nbsp; $songNumber songs</p>
<table>$songRows</table>
</body>
</html>''';
  }

  static Future<void> _openFile(String path) async {
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else {
      await Process.run('xdg-open', [path]);
    }
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
