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

  Future<List<({String title, String path, DateTime modified})>> listLibrary() async {
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

    final entries = <({String title, String path, DateTime modified})>[];
    for (final f in files) {
      try {
        final stat = await f.stat();
        final name = f.path.split('/').last
            .replaceAll(RegExp(r'\.(txt|lrc)$'), '');
        entries.add((title: name, path: f.path, modified: stat.modified));
      } catch (_) {}
    }
    entries.sort((a, b) => b.modified.compareTo(a.modified));
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
