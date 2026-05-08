import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/script_formatting.dart';

class FormattingService {
  Future<File> _file(String scriptTitle) async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/scripts');
    if (!await dir.exists()) await dir.create(recursive: true);
    final safe = scriptTitle.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
    final name = safe.isEmpty ? '_untitled' : safe;
    return File('${dir.path}/$name.fmt.json');
  }

  Future<ScriptFormatting> load(String scriptTitle) async {
    try {
      final file = await _file(scriptTitle);
      if (!await file.exists()) return ScriptFormatting.empty;
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return ScriptFormatting.fromJson(raw);
    } catch (_) {
      return ScriptFormatting.empty;
    }
  }

  Future<void> save(String scriptTitle, ScriptFormatting formatting) async {
    try {
      final file = await _file(scriptTitle);
      await file.writeAsString(jsonEncode(formatting.toJson()));
    } catch (_) {}
  }

  Future<void> delete(String scriptTitle) async {
    try {
      final file = await _file(scriptTitle);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
