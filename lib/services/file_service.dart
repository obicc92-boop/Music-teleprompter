import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class FileService {
  static const List<String> _allowedExtensions = ['txt', 'lrc', 'md'];

  Future<({String content, String title})?> openFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    if (file.path == null) return null;

    final content = await File(file.path!).readAsString();
    final title = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    return (content: content, title: title);
  }

  Future<bool> saveFile(String content, String suggestedName) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Script',
      fileName: '$suggestedName.txt',
      type: FileType.custom,
      allowedExtensions: ['txt', 'lrc'],
    );

    if (path == null) return false;

    await File(path).writeAsString(content);
    return true;
  }

  Future<String?> loadBundledScript(String assetName) async {
    try {
      return await rootBundle.loadString('assets/scripts/$assetName');
    } catch (_) {
      return null;
    }
  }

  Future<Directory> getScriptsDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final scriptsDir = Directory('${appDir.path}/scripts');
    if (!await scriptsDir.exists()) await scriptsDir.create(recursive: true);
    return scriptsDir;
  }

  Future<bool> saveToLibrary(String content, String title) async {
    final dir = await getScriptsDirectory();
    final safe = title.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
    final name = safe.isEmpty ? 'untitled' : safe;
    final file = File('${dir.path}/$name.txt');
    await file.writeAsString(content);
    return true;
  }

  Future<void> saveSetlistMeta({
    required List<String> orderedFilenames,
    required Map<String, int> colorValues,
  }) async {
    final dir = await getScriptsDirectory();
    final file = File('${dir.path}/_setlist.json');
    await file.writeAsString(jsonEncode({
      'order': orderedFilenames,
      'colors': colorValues,
    }));
  }

  Future<({List<String> order, Map<String, int> colors})> loadSetlistMeta() async {
    final dir = await getScriptsDirectory();
    final file = File('${dir.path}/_setlist.json');
    if (!await file.exists()) {
      return (order: <String>[], colors: <String, int>{});
    }
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final order = List<String>.from(raw['order'] as List? ?? []);
      final rawColors = (raw['colors'] as Map?)?.cast<String, dynamic>() ?? {};
      final colors = rawColors.map((k, v) => MapEntry(k, (v as num).toInt()));
      return (order: order, colors: colors);
    } catch (_) {
      return (order: <String>[], colors: <String, int>{});
    }
  }

  Future<List<({String title, String path, DateTime modified, int colorValue})>> listLibrary() async {
    final dir = await getScriptsDirectory();
    if (!await dir.exists()) return [];
    final entities = await dir.list().toList();
    final files = entities
        .whereType<File>()
        .where((f) {
          final name = f.path.split('/').last;
          return (name.endsWith('.txt') || name.endsWith('.lrc')) &&
              !name.startsWith('_');
        })
        .toList();

    final meta = await loadSetlistMeta();

    final entries = <({String title, String path, DateTime modified, int colorValue})>[];
    for (final f in files) {
      try {
        final stat = await f.stat();
        final filename = f.path.split('/').last;
        final title = filename.replaceAll(RegExp(r'\.(txt|lrc)$'), '');
        final colorValue = meta.colors[filename] ?? 0xFF555555;
        entries.add((
          title: title,
          path: f.path,
          modified: stat.modified,
          colorValue: colorValue,
        ));
      } catch (_) {}
    }

    entries.sort((a, b) {
      final af = a.path.split('/').last;
      final bf = b.path.split('/').last;
      final ai = meta.order.indexOf(af);
      final bi = meta.order.indexOf(bf);
      if (ai != -1 && bi != -1) return ai.compareTo(bi);
      if (ai != -1) return -1;
      if (bi != -1) return 1;
      return b.modified.compareTo(a.modified);
    });
    return entries;
  }

  Future<void> deleteFromLibrary(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<List<String>> listSavedScripts() async {
    final dir = await getScriptsDirectory();
    final files = await dir
        .list()
        .where((f) => f is File && (f.path.endsWith('.txt') || f.path.endsWith('.lrc')))
        .cast<File>()
        .toList();
    return files.map((f) => f.path).toList();
  }

  Future<String?> readSavedScript(String path) async {
    try {
      return await File(path).readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> autosave(String content, String title) async {
    final dir = await getScriptsDirectory();
    final file = File('${dir.path}/_autosave.txt');
    await file.writeAsString('# $title\n\n$content');
  }

  Future<String?> loadAutosave() async {
    try {
      final dir = await getScriptsDirectory();
      final file = File('${dir.path}/_autosave.txt');
      if (await file.exists()) return await file.readAsString();
      return null;
    } catch (_) {
      return null;
    }
  }
}
