import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/models/script_formatting.dart';
import 'package:music_teleprompter/models/song_settings.dart';
import 'package:music_teleprompter/services/file_service.dart';
import 'package:music_teleprompter/services/formatting_service.dart';
import 'package:music_teleprompter/services/setlist_service.dart';
import 'package:music_teleprompter/services/song_library.dart';
import 'package:music_teleprompter/services/song_lrc_content_store.dart';
import 'package:music_teleprompter/services/song_settings_store.dart';
import 'package:music_teleprompter/services/song_transpose_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory appDir;

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('teleprompter_rename_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => appDir.path,
    );
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => appDir.delete(recursive: true));

  test('renaming a song keeps it in the setlist with all its settings',
      () async {
    final files = FileService();
    final oldPath = await files.saveToLibrary('[Verse 1]\nLa la la', 'Lalala');
    await SongSettingsStore.saveSettings(
        'Lalala', const SongSettings(scrollSpeedMultiplier: 1.4));
    await SongLrcContentStore.saveContent('Lalala', '[00:01.00]La la la');
    await SongTransposeStore.saveTranspose('Lalala', 2);
    await FormattingService()
        .save('Lalala', ScriptFormatting.empty.apply(10, 12, bold: true));

    final scripts = Directory('${appDir.path}/scripts');
    await File('${scripts.path}/setlists.json').writeAsString(jsonEncode([
      {
        'id': '1',
        'name': 'Concert',
        'items': [
          {'id': 'a', 'type': 'song', 'title': 'Lalala', 'path': oldPath},
          {'id': 'b', 'type': 'separator', 'text': 'Break'},
        ],
      },
      {
        'id': '2',
        'name': 'Rehearsal',
        'items': [
          {'id': 'c', 'type': 'song', 'title': 'Lalala', 'path': oldPath},
        ],
      },
    ]));

    final newPath = await SongLibrary.rename(
      from: 'Lalala',
      to: 'La La La (live)',
      content: '[Verse 1]\nLa la la, live',
    );

    // The file moved and carries the new words
    expect(await File(oldPath).exists(), false);
    expect(await File(newPath).readAsString(), '[Verse 1]\nLa la la, live');
    expect(newPath, endsWith('La La La live.txt'));

    // Every setlist points at the new song; other entries are untouched
    final setlists = await SetlistService().load();
    for (final s in setlists) {
      final song = s.items.firstWhere((i) => i.isSong);
      expect(song.title, 'La La La (live)');
      expect(song.path, newPath);
    }
    expect(setlists.first.items[1].isSeparator, true);

    // Its settings, timing, key and formatting followed it
    expect(
        (await SongSettingsStore.getSettings('La La La (live)'))
            .scrollSpeedMultiplier,
        1.4);
    expect((await SongSettingsStore.getSettings('Lalala')).isEmpty, true);
    expect(await SongLrcContentStore.getContent('La La La (live)'),
        '[00:01.00]La la la');
    expect(await SongLrcContentStore.getContent('Lalala'), isNull);
    expect(await SongTransposeStore.getTranspose('La La La (live)'), 2);
    expect(await File('${scripts.path}/La La La live.fmt.json').exists(), true);
    expect(await File('${scripts.path}/Lalala.fmt.json').exists(), false);
  });

  test('deleting a song removes its file, its data and its setlist entries',
      () async {
    final files = FileService();
    final path = await files.saveToLibrary('la la', 'Lalala');
    final other = await files.saveToLibrary('do re', 'Doremi');
    await SongSettingsStore.saveSettings(
        'Lalala', const SongSettings(scrollSpeedMultiplier: 1.4));
    await SongLrcContentStore.saveContent('Lalala', '[00:01.00]La la la');
    await SongTransposeStore.saveTranspose('Lalala', 2);
    await FormattingService()
        .save('Lalala', ScriptFormatting.empty.apply(0, 2, bold: true));

    final scripts = Directory('${appDir.path}/scripts');
    await File('${scripts.path}/setlists.json').writeAsString(jsonEncode([
      {
        'id': '1',
        'name': 'Concert',
        'items': [
          // Older entries were saved with the other kind of slash, and a
          // setlist keeps the full title where the file can't
          {
            'id': 'a',
            'type': 'song',
            'title': 'La, la, la!',
            'path': path.contains('/')
                ? path.replaceAll('/', r'\')
                : path.replaceAll(r'\', '/'),
          },
          {'id': 'b', 'type': 'separator', 'text': 'Break'},
          {'id': 'c', 'type': 'song', 'title': 'Doremi', 'path': other},
        ],
      },
    ]));

    await SongLibrary.delete(title: 'Lalala', path: path);

    expect(await File(path).exists(), false);
    expect(await File(other).exists(), true);
    expect(await File('${scripts.path}/Lalala.fmt.json').exists(), false);
    expect((await SongSettingsStore.getSettings('Lalala')).isEmpty, true);
    expect(await SongLrcContentStore.getContent('Lalala'), isNull);
    expect(await SongTransposeStore.getTranspose('Lalala'), 0);

    final setlist = (await SetlistService().load()).single;
    expect(setlist.items.map((i) => i.id), ['b', 'c']);
  });

  test('a song can take a title that only differs in punctuation', () async {
    final files = FileService();
    await files.saveToLibrary('la', 'Lalala');
    // Its own file doesn't count as taken…
    expect(await files.uniqueLibraryTitle('Lalala!', keeping: 'Lalala'),
        'Lalala!');
    // …but another song's does
    expect(await files.uniqueLibraryTitle('Lalala!'), 'Lalala! 2');
  });
}
