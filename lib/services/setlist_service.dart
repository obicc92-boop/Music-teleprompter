import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/setlist_models.dart';

class SetlistService {
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/scripts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<Setlist>> load() async {
    final dir = await _dir();
    final file = File('${dir.path}/setlists.json');

    if (await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
        final list =
            raw.map((j) => Setlist.fromJson(j as Map<String, dynamic>)).toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    // Migrate from legacy _setlist.json
    final legacy = File('${dir.path}/_setlist.json');
    if (await legacy.exists()) {
      final migrated = await _migrate(dir, legacy);
      await save(migrated);
      return migrated;
    }

    final fresh = [_blank()];
    await save(fresh);
    return fresh;
  }

  Future<void> save(List<Setlist> setlists) async {
    final dir = await _dir();
    final file = File('${dir.path}/setlists.json');
    await file
        .writeAsString(jsonEncode(setlists.map((s) => s.toJson()).toList()));
  }

  Future<List<({String title, String path})>> librarySongs() async {
    final dir = await _dir();
    if (!await dir.exists()) return [];
    final entities = await dir.list().toList();
    final songs = <({String title, String path})>[];
    for (final e in entities) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (name.startsWith('_')) continue;
      if (!name.endsWith('.txt') && !name.endsWith('.lrc')) continue;
      final title = name.replaceAll(RegExp(r'\.(txt|lrc)$'), '');
      songs.add((title: title, path: e.path));
    }
    songs.sort((a, b) => a.title.compareTo(b.title));
    return songs;
  }

  Future<List<Setlist>> _migrate(Directory dir, File legacy) async {
    try {
      final raw =
          jsonDecode(await legacy.readAsString()) as Map<String, dynamic>;
      final order = List<String>.from(raw['order'] as List? ?? []);
      final rawColors =
          (raw['colors'] as Map?)?.cast<String, dynamic>() ?? {};
      final colors =
          rawColors.map((k, v) => MapEntry(k, (v as num).toInt()));

      final seen = <String>{};
      final items = <SetlistItem>[];

      for (final filename in order) {
        final path = '${dir.path}/$filename';
        if (seen.contains(filename) || !await File(path).exists()) continue;
        seen.add(filename);
        final title = filename.replaceAll(RegExp(r'\.(txt|lrc)$'), '');
        items.add(SetlistItem.song(
          path: path,
          title: title,
          colorValue: colors[filename] ?? 0xFF555555,
        ));
      }

      // Include any library songs not in the ordered list
      final entities = await dir.list().toList();
      for (final e in entities) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        if (name.startsWith('_') || seen.contains(name)) continue;
        if (!name.endsWith('.txt') && !name.endsWith('.lrc')) continue;
        seen.add(name);
        final title = name.replaceAll(RegExp(r'\.(txt|lrc)$'), '');
        items.add(SetlistItem.song(
          path: e.path,
          title: title,
          colorValue: colors[name] ?? 0xFF555555,
        ));
      }

      return [Setlist(id: _newId(), name: 'My Setlist', items: items)];
    } catch (_) {
      return [_blank()];
    }
  }

  Setlist _blank() =>
      Setlist(id: _newId(), name: 'My Setlist', items: const []);

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
