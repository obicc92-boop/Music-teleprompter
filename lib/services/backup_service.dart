import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

// Friendly label shown in the snackbar after an auto-backup
String backupLocationLabel(String path) {
  if (path.contains('CloudDocs')) return 'iCloud Drive';
  if (path.contains('MusicTeleprompter')) return 'Documents folder';
  return path;
}

class BackupService {
  /// Creates a JSON bundle of all setlists + script files.
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
        if (!name.endsWith('.txt') && !name.endsWith('.lrc')) continue;
        try {
          scripts[name] = await e.readAsString();
        } catch (_) {}
      }
    }

    final bundle = jsonEncode({
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'setlists': setlistsJson,
      'scripts': scripts,
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

  /// Prompts the user to pick a backup file, restores scripts + setlists.
  /// Returns the number of script files restored.
  Future<int> restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Open Backup File',
    );
    if (result == null || result.files.isEmpty) return 0;
    final path = result.files.first.path;
    if (path == null) return 0;

    final raw = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    if ((raw['version'] as int?) != 1) {
      throw const FormatException('Unrecognised backup format.');
    }

    final scriptsDir = await _scriptsDir();
    if (!await scriptsDir.exists()) await scriptsDir.create(recursive: true);

    final scripts = (raw['scripts'] as Map<String, dynamic>?) ?? {};
    for (final entry in scripts.entries) {
      await File('${scriptsDir.path}/${entry.key}')
          .writeAsString(entry.value as String);
    }

    final setlistsJson = raw['setlists'];
    if (setlistsJson != null) {
      await File('${scriptsDir.path}/setlists.json')
          .writeAsString(jsonEncode(setlistsJson));
    }

    return scripts.length;
  }

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
