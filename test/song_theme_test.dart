import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/models/song_settings.dart';
import 'package:music_teleprompter/models/song_theme.dart';
import 'package:music_teleprompter/services/settings_service.dart';
import 'package:music_teleprompter/services/song_settings_store.dart';
import 'package:music_teleprompter/widgets/theme_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SongTheme', () {
    test('presets and custom colours survive saving', () {
      for (final preset in SongTheme.presets) {
        expect(SongTheme.fromCode(preset.code), preset);
      }
      final custom = SongTheme.custom(
        background: const Color(0xFF12203A),
        accent: const Color(0xFFFFD166),
      );
      expect(custom.code, 'custom:12203A:FFD166');
      final restored = SongTheme.fromCode(custom.code);
      expect(restored.isCustom, true);
      expect(restored.background.toARGB32(), 0xFF12203A);
      expect(restored.accent.toARGB32(), 0xFFFFD166);
    });

    test('unknown or broken codes fall back to Classic', () {
      expect(SongTheme.fromCode(null), SongTheme.defaultTheme);
      expect(SongTheme.fromCode('sparkly'), SongTheme.defaultTheme);
      expect(SongTheme.fromCode('custom:ZZZZZZ:FFFFFF'), SongTheme.defaultTheme);
      expect(SongTheme.fromCode('custom:000000'), SongTheme.defaultTheme);
    });

    test('Pure black is really black', () {
      expect(SongTheme.fromCode('black').background.toARGB32(), 0xFF000000);
    });

    test('lyrics are light on dark backgrounds and dark on light ones', () {
      final dark = SongTheme.custom(
          background: const Color(0xFF000000), accent: const Color(0xFFFF6B35));
      final light = SongTheme.custom(
          background: const Color(0xFFF4F1EA), accent: const Color(0xFFB3261E));
      expect(dark.text.toARGB32(), 0xFFFFFFFF);
      expect(light.text.computeLuminance(), lessThan(0.05));
    });

    test('every preset reads well; poor custom colours get a warning', () {
      for (final preset in SongTheme.presets) {
        expect(preset.readabilityWarnings, isEmpty, reason: preset.label);
      }
      final grey = SongTheme.custom(
          background: const Color(0xFF6E6E6E), accent: const Color(0xFFFF6B35));
      expect(grey.readabilityWarnings.first, contains('hard to read'));

      final bright = SongTheme.custom(
          background: const Color(0xFFFFFFFF), accent: const Color(0xFF0050C8));
      expect(bright.readabilityWarnings.single, contains('dazzle'));

      final hiddenHighlight = SongTheme.custom(
          background: const Color(0xFF101010), accent: const Color(0xFF1C1C1C));
      expect(hiddenHighlight.readabilityWarnings.single,
          contains('hardly stands out'));
    });
  });

  group('Colour theme as a song setting', () {
    const defaults = AppSettings(colorTheme: 'ocean');

    test('a song uses the default theme unless it has its own', () {
      expect(SongSettings.none.applyTo(defaults).songTheme.id, 'ocean');
      const own = SongSettings(colorTheme: 'custom:1A0010:FF4FA3');
      expect(own.applyTo(defaults).songTheme.isCustom, true);
      expect(own.withColorTheme(null).isEmpty, true);
    });

    test('picking a colour during a song keeps only that change', () {
      final before = SongSettings.none.applyTo(defaults);
      final after = before.copyWith(colorTheme: 'black');
      final updated = SongSettings.none.withChanges(before, after);
      expect(updated.colorTheme, 'black');
      expect(updated.fontSize, isNull);
      expect(SongSettings.fromJson(updated.toJson()).colorTheme, 'black');
    });

    test('themes saved by earlier versions move into the song settings',
        () async {
      SharedPreferences.setMockInitialValues({
        'theme_Lalala': 'red',
        'song_settings_Lalala': '{"fontSize":70.0}',
      });
      final settings = await SongSettingsStore.getSettings('Lalala');
      expect(settings.colorTheme, 'red');
      expect(settings.fontSize, 70);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('theme_Lalala'), false);
      expect((await SongSettingsStore.getSettings('Lalala')).colorTheme, 'red');
    });
  });

  group('ThemePicker', () {
    Future<List<SongTheme>> pumpPicker(WidgetTester tester, SongTheme start,
        {double width = 395}) async {
      final picked = <SongTheme>[];
      var value = start;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => ThemePicker(
                width: width,
                value: value,
                onChanged: (t) {
                  picked.add(t);
                  setState(() => value = t);
                },
              ),
            ),
          ),
        ),
      ));
      return picked;
    }

    testWidgets('a tile picks its theme', (tester) async {
      final picked = await pumpPicker(tester, SongTheme.defaultTheme);
      await tester.tap(find.text('Pure black'));
      expect(picked.single.id, 'black');
      expect(find.text('Background'), findsNothing);
    });

    testWidgets('Custom starts from the current colours and can be edited',
        (tester) async {
      final ocean = SongTheme.fromCode('ocean');
      final picked = await pumpPicker(tester, ocean);
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      expect(picked.last.isCustom, true);
      expect(picked.last.background, ocean.background);
      expect(find.text('Background'), findsOneWidget);
      expect(find.text('Highlight'), findsOneWidget);

      // Typing a hex code changes the background being edited
      await tester.enterText(find.byType(TextField), '2B0A3D');
      await tester.pump();
      expect(picked.last.background.toARGB32(), 0xFF2B0A3D);
      expect(picked.last.accent, ocean.accent);

      // Dragging brightness all the way down gives black
      final brightness = find.byType(GradientSlider).at(2);
      await tester.drag(brightness, const Offset(-600, 0));
      await tester.pump();
      expect(picked.last.background.toARGB32(), 0xFF000000);
    });

    testWidgets('fits a narrow Settings panel and a dialog',
        (tester) async {
      for (final width in [300.0, 400.0]) {
        await pumpPicker(tester,
            SongTheme.custom(
                background: const Color(0xFF6E6E6E),
                accent: const Color(0xFF777777)),
            width: width);
        await tester.pumpAndSettle();
        // A layout overflow would already have failed the test
        expect(find.textContaining('hard to read'), findsOneWidget);
      }
    });

    testWidgets('the in-song dialog can go back to the default', (tester) async {
      final changes = <SongTheme>[];
      var resets = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => SongThemeDialog(
                  theme: SongTheme.fromCode('ocean'),
                  defaultTheme: SongTheme.defaultTheme,
                  hasOwnTheme: true,
                  onChanged: changes.add,
                  onReset: () => resets++,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Amber'));
      await tester.pump();
      expect(changes.single.id, 'amber');

      await tester.tap(find.text('Use default colours'));
      await tester.pump();
      expect(resets, 1);
      expect(find.text('Use default colours'), findsNothing);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(SongThemeDialog), findsNothing);
    });
  });
}
