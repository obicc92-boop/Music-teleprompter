import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class VoiceProfileService {
  static const _filename = 'voice_profile.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_filename');
  }

  Future<void> save(List<double> profile) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(profile));
  }

  Future<List<double>?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
