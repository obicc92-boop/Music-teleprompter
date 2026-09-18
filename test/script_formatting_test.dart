import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/models/script_formatting.dart';
import 'package:music_teleprompter/services/script_parser.dart';
import 'package:music_teleprompter/utils/app_theme.dart';
import 'package:music_teleprompter/widgets/formatted_text_controller.dart';
import 'package:music_teleprompter/widgets/lyrics_format_toolbar.dart';

void main() {
  const lyrics = '[Verse 1]\nShine shine shine\nIn F\n\nWaking up in the glow';
  //             0123456789
  // "Shine shine shine" starts at 10; "In F" at 28; "Waking…" at 34

  group('ScriptFormatting', () {
    test('colours a range and keeps other looks the characters had', () {
      var f = ScriptFormatting.empty.apply(10, 27, bold: true);
      f = f.apply(16, 21, colorValue: 0xFFFF0000);
      expect(f.spans.map((s) => (s.start, s.end, s.bold, s.colorValue)), [
        (10, 16, true, null),
        (16, 21, true, 0xFFFF0000),
        (21, 27, true, null),
      ]);
      // Neighbours with the same look are joined back up
      f = f.clear(16, 21).apply(16, 21, bold: true);
      expect(f.spans.length, 1);
      expect(f.spans.single.end, 27);
    });

    test('typing inside a coloured phrase extends it; before or after it does not',
        () {
      final f = ScriptFormatting.empty.apply(10, 15, colorValue: 1); // "Shine"
      final inside = f.edited(lyrics, lyrics.replaceFirst('Shine', 'Shiine'));
      expect((inside.spans.single.start, inside.spans.single.end), (10, 16));

      final before = f.edited(lyrics, lyrics.replaceFirst('[Verse 1]', '[Verse One]'));
      expect((before.spans.single.start, before.spans.single.end), (12, 17));

      final after = f.edited(lyrics, lyrics.replaceFirst('Shine ', 'Shine! '));
      expect((after.spans.single.start, after.spans.single.end), (10, 15));
    });

    test('deleting part of a phrase shrinks it; replacing it all drops it', () {
      final f = ScriptFormatting.empty.apply(10, 27, colorValue: 1);
      final trimmed = f.edited(lyrics, lyrics.replaceFirst('shine shine', 'shine'));
      expect((trimmed.spans.single.start, trimmed.spans.single.end), (10, 21));

      final gone = f.edited(lyrics, lyrics.replaceFirst('Shine shine shine', 'La'));
      expect(gone.spans, isEmpty);
    });

    test('lines find their own runs by character offset', () {
      final script = ScriptParser.parse(lyrics);
      final f = ScriptFormatting.empty
          .apply(16, 21, colorValue: 1) // second "shine"
          .apply(28, 32, bold: true); // "In F"
      final shine = script.allLines[1];
      expect(shine.rawStart, 10);
      final runs = f.forLine(shine);
      expect((runs.single.start, runs.single.end), (6, 11));
      expect(f.forLine(script.allLines[2]).single.bold, true);
      expect(f.forLine(script.allLines[4]), isEmpty);
    });

    test('indented lines still know where their text starts', () {
      final script = ScriptParser.parse('  Hello\n\tWorld');
      expect(script.allLines[0].rawStart, 2);
      expect(script.allLines[1].rawStart, 9);
    });

    test('formats saved by earlier versions move onto the words', () {
      final script = ScriptParser.parse(lyrics);
      final old = ScriptFormatting.fromJson({
        'entries': [
          {'lineIndex': 1, 'wordIndex': 2, 'colorValue': 0xFF00FF00, 'bold': true},
        ],
      });
      expect(old.legacy.length, 1);
      final upgraded = old.upgraded(script);
      expect(upgraded.legacy, isEmpty);
      expect((upgraded.spans.single.start, upgraded.spans.single.end), (22, 27));
      expect(upgraded.spans.single.colorValue, 0xFF00FF00);
      // Round trip in the new shape
      expect(ScriptFormatting.fromJson(upgraded.toJson()).spans.single.end, 27);
    });
  });

  group('FormattedTextController', () {
    test('styles whole words around a caret or a partial selection', () {
      final c = FormattedTextController(text: lyrics);
      c.selection = const TextSelection.collapsed(offset: 18); // inside "shine"
      expect(c.targetWords, const TextRange(start: 16, end: 21));

      c.selection = const TextSelection(baseOffset: 12, extentOffset: 19);
      c.style(colorValue: 0xFF0000FF);
      expect((c.formatting.spans.single.start, c.formatting.spans.single.end),
          (10, 21));
      // The styled words stay selected for the next button
      expect((c.selection.start, c.selection.end), (10, 21));
      expect(c.targetLook?.colorValue, 0xFF0000FF);

      // A caret right after a word still means that word…
      c.selection = const TextSelection.collapsed(offset: 32); // after "F"
      expect(c.targetWords, const TextRange(start: 31, end: 32));
      // …but an empty line means nothing
      c.selection = const TextSelection.collapsed(offset: 33);
      expect(c.targetWords, isNull);
      c.dispose();
    });

    test('bold toggles and sizes step; clearing returns to plain lyrics', () {
      final c = FormattedTextController(text: lyrics);
      c.selection = const TextSelection(baseOffset: 28, extentOffset: 32);
      c.toggleBold();
      expect(c.targetLook?.bold, true);
      c.stepFontSize(1);
      c.stepFontSize(1);
      expect(c.targetLook?.fontSizeScale, 1.3);
      c.toggleBold();
      expect(c.targetLook?.bold, false);
      expect(c.targetLook?.fontSizeScale, 1.3);
      c.clearStyle();
      expect(c.formatting.spans, isEmpty);
      c.dispose();
    });

    test('formatting follows the text as the user types', () {
      final c = FormattedTextController(text: lyrics);
      c.selection = const TextSelection(baseOffset: 28, extentOffset: 32);
      c.style(colorValue: 1);
      c.value = TextEditingValue(text: 'Intro\n$lyrics');
      final s = c.formatting.spans.single;
      expect((s.start, s.end), (34, 38));
      c.dispose();
    });
  });

  group('LyricsFormatToolbar', () {
    setUpAll(() async {
      final loader = FontLoader('AppSans');
      for (final file in ['Manrope-Regular.ttf', 'Manrope-SemiBold.ttf']) {
        final bytes = await File('assets/fonts/$file').readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    });

    testWidgets('a swatch colours the selected words and the editor keeps focus',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = FormattedTextController(text: lyrics);
      addTearDown(c.dispose);
      final group = Object();
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Column(
            children: [
              LyricsFormatToolbar(controller: c, tapGroup: group),
              Expanded(
                child: TextField(
                  controller: c,
                  groupId: group,
                  maxLines: null,
                  expands: true,
                ),
              ),
            ],
          ),
        ),
      ));

      expect(find.textContaining('Click a word'), findsOneWidget);

      await tester.showKeyboard(find.byType(TextField));
      await tester.pump();
      c.selection = const TextSelection(baseOffset: 10, extentOffset: 27);
      await tester.pump();
      expect(find.textContaining('Click a word'), findsNothing);

      await tester.tap(find.byTooltip('Colour').first);
      await tester.pump();
      expect(c.formatting.spans.single.colorValue,
          LyricsFormatToolbar.palette.first);
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isA<Focus>().having((f) => f.debugLabel, 'label', 'EditableText'),
      );

      await tester.tap(find.text('B'));
      await tester.pump();
      expect(c.formatting.spans.single.bold, true);
      expect(find.text('100%'), findsOneWidget);
      await tester.tap(find.text('A+'));
      await tester.pump();
      expect(find.text('115%'), findsOneWidget);
    });
  });
}
