import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/engine/scroll_engine.dart';
import 'package:music_teleprompter/engine/sync_engine.dart';
import 'package:music_teleprompter/models/song_settings.dart';
import 'package:music_teleprompter/services/script_parser.dart';
import 'package:music_teleprompter/services/settings_service.dart';
import 'package:music_teleprompter/services/song_settings_store.dart';
import 'package:music_teleprompter/views/settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const defaults = AppSettings(
    fontSize: 52,
    scrollSpeedMultiplier: 1.0,
    displayFont: 'TeleprompterMono',
  );

  group('SongSettings', () {
    test('a song without its own settings uses the defaults', () {
      final s = SongSettings.none.applyTo(defaults);
      expect(s.fontSize, 52);
      expect(s.scrollSpeedMultiplier, 1.0);
      expect(SongSettings.none.isEmpty, true);
    });

    test('own values replace only the matching defaults', () {
      const song = SongSettings(fontSize: 80, scrollSpeedMultiplier: 1.6);
      final s = song.applyTo(defaults.copyWith(textAlignLeft: true));
      expect(s.fontSize, 80);
      expect(s.scrollSpeedMultiplier, 1.6);
      expect(s.displayFont, 'TeleprompterMono');
      expect(s.textAlignLeft, true);
    });

    test('withChanges keeps only what was changed, plus earlier changes', () {
      const song = SongSettings(scrollSpeedMultiplier: 1.4);
      final before = song.applyTo(defaults);
      final after = before.copyWith(fontSize: 70);
      final updated = song.withChanges(before, after);
      expect(updated.fontSize, 70);
      expect(updated.scrollSpeedMultiplier, 1.4);
      expect(updated.displayFont, isNull);
      expect(updated.activeLineYOffset, isNull);
    });

    test('changes to settings that are not per song are ignored', () {
      final before = SongSettings.none.applyTo(defaults);
      final after = before.copyWith(autoAdvance: false, pedalAction: 'nextSong');
      expect(SongSettings.none.withChanges(before, after).isEmpty, true);
    });

    test('withSpeed(null) goes back to the default speed', () {
      const song = SongSettings(scrollSpeedMultiplier: 2.0, fontSize: 60);
      final cleared = song.withSpeed(null);
      expect(cleared.scrollSpeedMultiplier, isNull);
      expect(cleared.fontSize, 60);
    });

    test('JSON round trip', () {
      const song = SongSettings(
        scrollSpeedMultiplier: 1.25,
        fontSize: 64,
        displayFont: 'TeleprompterOswald',
        textAlignLeft: true,
        showActiveLineHighlight: false,
        activeLineYOffset: 0.5,
      );
      final restored = SongSettings.fromJson(song.toJson());
      expect(restored.toJson(), song.toJson());
      expect(SongSettings.none.toJson(), isEmpty);
    });
  });

  group('SongSettingsStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves per song title and resets to defaults', () async {
      await SongSettingsStore.saveSettings(
          'Ballad', const SongSettings(scrollSpeedMultiplier: 0.6));
      expect(
          (await SongSettingsStore.getSettings('Ballad')).scrollSpeedMultiplier,
          0.6);
      expect((await SongSettingsStore.getSettings('Anthem')).isEmpty, true);

      await SongSettingsStore.saveSettings('Ballad', SongSettings.none);
      expect((await SongSettingsStore.getSettings('Ballad')).isEmpty, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });
  });

  test('changing line height keeps the reading position', () {
    final scroll = ScrollEngine(syncEngine: SyncEngine());
    scroll.setScript(
        ScriptParser.parse(List.generate(20, (i) => 'Line $i').join('\n')),
        100);
    scroll.jumpToLine(7);
    scroll.setLineHeight(160);
    expect(scroll.activeLineIndex, 7);
    expect(scroll.pixelOffset, 7 * 160);
  });

  group('SettingsView', () {
    // The default test font draws every glyph 1em wide; use the real one.
    setUpAll(() async {
      final loader = FontLoader('TeleprompterMono');
      for (final file in ['JetBrainsMono-Regular.ttf', 'JetBrainsMono-Bold.ttf']) {
        final bytes = await File('assets/fonts/$file').readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    });

    Future<void> pumpSettings(
      WidgetTester tester, {
      String? songTitle,
      bool songHasOwnSettings = false,
      VoidCallback? onReset,
    }) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SettingsView(
              settings: defaults,
              songTitle: songTitle,
              songHasOwnSettings: songHasOwnSettings,
              onChanged: (_) {},
              onResetSong: onReset ?? () {},
              onClose: () {},
            ),
          ),
        ),
      ));
    }

    testWidgets('from a song: names the song and offers Reset', (tester) async {
      const longTitle =
          'A Very Long Song Title — Featuring Somebody Else (Live Acoustic Version)';
      var resets = 0;
      await pumpSettings(tester,
          songTitle: longTitle,
          songHasOwnSettings: true,
          onReset: () => resets++);
      expect(find.text(longTitle), findsOneWidget);
      await tester.tap(find.text('Reset to default'));
      expect(resets, 1);
    });

    testWidgets('Reset does nothing when the song uses the defaults',
        (tester) async {
      var resets = 0;
      await pumpSettings(tester, songTitle: 'Slow Song', onReset: () => resets++);
      await tester.tap(find.text('Reset to default'));
      expect(resets, 0);
    });

    testWidgets('from the home screen: edits the defaults', (tester) async {
      await pumpSettings(tester);
      expect(find.text('Default settings'), findsOneWidget);
      expect(find.text('Reset to default'), findsNothing);
    });
  });
}
