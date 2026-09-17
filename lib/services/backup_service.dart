import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Friendly label shown in the snackbar after an auto-backup
String backupLocationLabel(String path) {
  if (path.contains('CloudDocs')) return 'iCloud Drive';
  if (path.contains('MusicTeleprompter')) return 'Documents folder';
  return path;
}

/// A backup file that has been read but not restored yet.
class BackupFile {
  final Map<String, dynamic> bundle;
  const BackupFile(this.bundle);

  DateTime? get createdAt =>
      DateTime.tryParse(bundle['createdAt'] as String? ?? '');
  int get setlistCount => (bundle['setlists'] as List?)?.length ?? 0;

  /// Backups made before settings were included only hold lyrics and setlists.
  bool get hasSettings => bundle['settings'] is Map;
  int get songCount => ((bundle['scripts'] as Map?)?.keys ?? const [])
      .where((name) => '$name'.endsWith('.txt') || '$name'.endsWith('.lrc'))
      .length;
}

class BackupService {
  // Song files only make sense on the computer they were picked on
  static const _deviceOnlyPrefixes = ['audio_path_', 'lrc_path_'];

  /// Saves setlists, songs, lyric formatting and every setting — each song's
  /// own settings, theme, transpose and timing, plus the defaults — so a show
  /// can move to another computer as a whole.
  /// Tries iCloud Drive first; falls back to a user-chosen save location.
  /// Returns the saved file path, or null if the user cancelled.
  Future<String?> backup(List<dynamic> setlistsJson) async {
    final scriptsDir = await _scriptsDir();
    final scripts = <String, String>{};

    if (await scriptsDir.exists()) {
      final entities = await scriptsDir.list().toList();
      for (final e in entities) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        if (!_isBackedUpFile(name)) continue;
        try {
          scripts[name] = await e.readAsString();
        } catch (_) {}
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final bundle = jsonEncode({
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'setlists': setlistsJson,
      'scripts': scripts,
      'settings': settingsForBackup(
          {for (final key in prefs.getKeys()) key: prefs.get(key)}),
    });

    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = 'MusicTeleprompterBackup_$dateStr.json';

    // Try auto-backup location (iCloud on macOS, Documents elsewhere)
    final autoPath = await _autoBackupPath(fileName);
    if (autoPath != null) {
      try {
        final dir = File(autoPath).parent;
        if (!await dir.exists()) await dir.create(recursive: true);
        await File(autoPath).writeAsString(bundle);
        return autoPath;
      } catch (_) {}
    }

    // Fall back to user-selected location
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (savePath == null) return null;
    await File(savePath).writeAsString(bundle);
    return savePath;
  }

  /// Asks for a backup file and reads it, without restoring anything yet.
  /// Returns null if the user cancelled; throws if it isn't a backup.
  Future<BackupFile?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Open Backup File',
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.first.path;
    if (path == null) return null;

    final raw = jsonDecode(await File(path).readAsString());
    if (raw is! Map<String, dynamic> || raw['version'] != 1) {
      throw const FormatException('Unrecognised backup format.');
    }
    return BackupFile(raw);
  }

  /// Writes the backup's songs, setlists and settings to this computer.
  /// Setlists are replaced; songs and settings in the backup are added or
  /// updated, and anything not in it is left alone.
  Future<void> restore(BackupFile backup) async {
    final scriptsDir = await _scriptsDir();
    if (!await scriptsDir.exists()) await scriptsDir.create(recursive: true);

    final scripts = (backup.bundle['scripts'] as Map<String, dynamic>?) ?? {};
    for (final entry in scripts.entries) {
      if (!_isSafeFileName(entry.key)) continue;
      await File('${scriptsDir.path}/${entry.key}')
          .writeAsString(entry.value as String);
    }

    final setlistsJson = backup.bundle['setlists'];
    if (setlistsJson is List) {
      await File('${scriptsDir.path}/setlists.json').writeAsString(
          jsonEncode(relinkSetlists(setlistsJson, scriptsDir.path)));
    }

    final settings = backup.bundle['settings'];
    if (settings is Map<String, dynamic>) {
      final prefs = await SharedPreferences.getInstance();
      for (final MapEntry(:key, :value) in settingsForBackup(settings).entries) {
        switch (value) {
          case bool v:
            await prefs.setBool(key, v);
          case int v:
            await prefs.setInt(key, v);
          case double v:
            await prefs.setDouble(key, v);
          case String v:
            await prefs.setString(key, v);
        }
      }
    }
  }

  /// The settings worth carrying to another computer.
  static Map<String, Object> settingsForBackup(Map<String, Object?> all) => {
        for (final MapEntry(:key, :value) in all.entries)
          if (!_deviceOnlyPrefixes.any(key.startsWith) &&
              (value is bool || value is int || value is double || value is String))
            key: value!,
      };

  /// Setlists remember each song's file by its full path, which only exists
  /// on the computer the backup came from. Points them into [scriptsDir].
  static List<dynamic> relinkSetlists(List<dynamic> setlists, String scriptsDir) => [
        for (final setlist in setlists)
          if (setlist is Map<String, dynamic>)
            {
              ...setlist,
              'items': [
                for (final item in (setlist['items'] as List? ?? const []))
                  if (item is Map<String, dynamic> &&
                      item['type'] != 'separator' &&
                      item['path'] is String &&
                      (item['path'] as String).isNotEmpty)
                    {
                      ...item,
                      'path':
                          '$scriptsDir/${(item['path'] as String).split(RegExp(r'[\\/]')).last}',
                    }
                  else
                    item,
              ],
            }
          else
            setlist,
      ];

  // Lyrics, synced lyrics and lyric formatting; internal files start with "_"
  static bool _isBackedUpFile(String name) =>
      !name.startsWith('_') &&
      (name.endsWith('.txt') || name.endsWith('.lrc') || name.endsWith('.fmt.json'));

  static bool _isSafeFileName(String name) =>
      _isBackedUpFile(name) && !name.contains('/') && !name.contains('\\') &&
      !name.contains('..');

  /// Returns an auto-backup file path without prompting the user:
  ///   macOS  → iCloud Drive / MusicTeleprompter /
  ///   Windows → Documents \ MusicTeleprompter \
  ///   Linux   → ~/Documents/MusicTeleprompter/
  Future<String?> _autoBackupPath(String fileName) async {
    try {
      if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home == null) return null;
        return '$home/Library/Mobile Documents/com~apple~CloudDocs/'
            'MusicTeleprompter/$fileName';
      } else if (Platform.isWindows) {
        final docs = await getApplicationDocumentsDirectory();
        return '${docs.path}\\MusicTeleprompter\\$fileName';
      } else {
        // Linux
        final home = Platform.environment['HOME'];
        if (home == null) return null;
        return '$home/Documents/MusicTeleprompter/$fileName';
      }
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _scriptsDir() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/scripts');
  }
}
