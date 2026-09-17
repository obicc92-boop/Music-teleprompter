import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backups carry song and default settings, not device file paths', () {
    final kept = BackupService.settingsForBackup({
      'font_size': 64.0,
      'auto_advance': true,
      'song_settings_Lalala': '{"scrollSpeedMultiplier":1.5}',
      'theme_Lalala': 'red',
      'transpose_Lalala': 2,
      'lrc_content_lalala': '[00:01.00]Hi',
      'audio_path_Lalala': 'C:\\Music\\lalala.mp3',
      'lrc_path_Lalala': 'C:\\Music\\lalala.lrc',
    });
    expect(kept.keys, unorderedEquals([
      'font_size',
      'auto_advance',
      'song_settings_Lalala',
      'theme_Lalala',
      'transpose_Lalala',
      'lrc_content_lalala',
    ]));
  });

  test('restoring on another computer points songs at its own song folder', () {
    final relinked = BackupService.relinkSetlists([
      {
        'name': 'Concert',
        'items': [
          {
            'type': 'song',
            'title': 'Lalala',
            'path': r'C:\Users\obich\AppData\Roaming\music_teleprompter/scripts\Lalala.txt',
          },
          {'type': 'separator', 'text': 'Break'},
          {
            'type': 'song',
            'title': 'Other',
            'path': '/Users/friend/Library/Containers/app/scripts/Other.txt',
          },
        ],
      },
    ], '/Users/friend/Library/scripts');

    final items = (relinked.single as Map)['items'] as List;
    expect(items[0]['path'], '/Users/friend/Library/scripts/Lalala.txt');
    expect(items[0]['title'], 'Lalala');
    expect(items[1], {'type': 'separator', 'text': 'Break'});
    expect(items[2]['path'], '/Users/friend/Library/scripts/Other.txt');
  });

  group('restore', () {
    late Directory appDir;

    setUp(() async {
      appDir = await Directory.systemTemp.createTemp('teleprompter_restore_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => appDir.path,
      );
      SharedPreferences.setMockInitialValues({'font_size': 40.0, 'keep_me': 'yes'});
    });

    tearDown(() => appDir.delete(recursive: true));

    test('a backup made on Windows restores songs, setlists and settings',
        () async {
      final backup = BackupFile(jsonDecode(jsonEncode({
        'version': 1,
        'createdAt': '2026-09-17T13:00:00.000',
        'setlists': [
          {
            'id': '1',
            'name': 'Concert',
            'items': [
              {
                'id': 'a',
                'type': 'song',
                'title': 'Lalala',
                'path': r'C:\Users\obich\AppData\Roaming\x\scripts/Lalala.txt',
              },
            ],
          },
        ],
        'scripts': {
          'Lalala.txt': '[Verse 1]\nLa la la',
          'Lalala.fmt.json': '{}',
          '../escape.txt': 'must not be written outside the song folder',
        },
        'settings': {
          'font_size': 72.0,
          'song_settings_Lalala': '{"scrollSpeedMultiplier":1.25}',
          'lrc_content_lalala': '[re:Music Teleprompter rehearsal]\n[00:02.00]La la la',
          'audio_path_Lalala': r'C:\Music\lalala.mp3',
        },
      })) as Map<String, dynamic>);

      expect(backup.setlistCount, 1);
      expect(backup.songCount, 2); // counts .txt/.lrc names, including the unsafe one
      await BackupService().restore(backup);

      final scripts = Directory('${appDir.path}/scripts');
      expect(File('${scripts.path}/Lalala.txt').readAsStringSync(),
          '[Verse 1]\nLa la la');
      expect(File('${scripts.path}/Lalala.fmt.json').existsSync(), true);
      expect(File('${appDir.path}/escape.txt').existsSync(), false);

      final setlists = jsonDecode(
          File('${scripts.path}/setlists.json').readAsStringSync()) as List;
      expect(setlists.single['items'][0]['path'], '${scripts.path}/Lalala.txt');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('font_size'), 72.0);
      expect(prefs.getString('song_settings_Lalala'),
          '{"scrollSpeedMultiplier":1.25}');
      expect(prefs.getString('lrc_content_lalala'), contains('[00:02.00]'));
      expect(prefs.getString('audio_path_Lalala'), isNull);
      expect(prefs.getString('keep_me'), 'yes');
    });
  });
}
