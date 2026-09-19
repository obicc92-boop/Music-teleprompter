import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/models/script_formatting.dart';
import 'package:music_teleprompter/services/line_edit.dart';
import 'package:music_teleprompter/services/script_parser.dart';
import 'package:music_teleprompter/utils/app_theme.dart';
import 'package:music_teleprompter/widgets/inline_line_editor.dart';

void main() {
  const lyrics = '[Verse 1]\nShine shine shine\nIn F\nWaking up';
  // line 1 "Shine shine shine" at 10–27, line 2 "In F" at 28–32, line 3 at 33

  group('LineEdit.replaceRange', () {
    test('the rewritten line takes its new look; later lines slide along', () {
      final before = ScriptFormatting.empty
          .apply(10, 15, colorValue: 1) // "Shine" on the edited line
          .apply(33, 39, bold: true); // "Waking" two lines down
      final look = ScriptFormatting.empty.apply(0, 4, colorValue: 2); // "Sing"
      final after = LineEdit.replaceRange(
          before, lyrics, 10, 27, 'Sing it loud', look);
      // "Sing it loud" is 12 long instead of 17: everything after moves by -5
      expect(after.spans.map((s) => (s.start, s.end, s.colorValue, s.bold)), [
        (10, 14, 2, false),
        (28, 34, null, true),
      ]);
    });

    test('splitting a line keeps the look on both halves', () {
      final look = ScriptFormatting.empty.apply(0, 11, bold: true);
      final after = LineEdit.replaceRange(
          ScriptFormatting.empty, lyrics, 10, 27, 'Shine\nshine shine', look);
      expect((after.spans.single.start, after.spans.single.end), (10, 21));
    });
  });

  group('LineEdit.retime', () {
    // Lines 1, 2, 3 timed at 10, 20 and 30 seconds
    const timeline = [(1, 10.0), (2, 20.0), (3, 30.0)];

    test('splitting a line: the new line lands between its neighbours', () {
      final script = ScriptParser.parse('[Verse 1]\nShine\nshine shine\nIn F\nWaking up');
      final times = LineEdit.retime(script, 1, 1, timeline);
      expect(times, {1: 10.0, 2: 15.0, 3: 20.0, 4: 30.0});
    });

    test('splitting the last line paces the new one three seconds later', () {
      final script = ScriptParser.parse('[Verse 1]\nShine shine shine\nIn F\nWaking\nup');
      final times = LineEdit.retime(script, 3, 1, timeline);
      expect(times, {1: 10.0, 2: 20.0, 3: 30.0, 4: 33.0});
    });

    test("a blank line pushed in above keeps the line's own time", () {
      final script =
          ScriptParser.parse('[Verse 1]\n\nShine shine shine\nIn F\nWaking up');
      final times = LineEdit.retime(script, 1, 1, timeline);
      expect(times, {2: 10.0, 3: 20.0, 4: 30.0});
    });

    test('removing a line: the others keep their own times', () {
      final script = ScriptParser.parse('[Verse 1]\nIn F\nWaking up');
      // Line 1 was emptied and its blank removed, so the song is one shorter
      final times = LineEdit.retime(script, 1, -1, timeline);
      expect(times, {1: 20.0, 2: 30.0});
    });
  });

  group('InlineLineEditor', () {
    setUpAll(() async {
      final loader = FontLoader('AppSans');
      for (final file in ['Manrope-Regular.ttf', 'Manrope-SemiBold.ttf']) {
        final bytes = await File('assets/fonts/$file').readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    });

    Future<(List<(String, ScriptFormatting)>, List<int>)> pump(
        WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final saved = <(String, ScriptFormatting)>[];
      final cancels = <int>[];
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 900,
              child: InlineLineEditor(
                text: 'Shine shine shine',
                spans: const [FormatSpan(start: 0, end: 5, bold: true)],
                style: const TextStyle(fontSize: 40, color: Colors.white),
                textAlign: TextAlign.center,
                accent: Colors.orange,
                textColor: Colors.white,
                onSave: (t, f) => saved.add((t, f)),
                onCancel: () => cancels.add(1),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      return (saved, cancels);
    }

    testWidgets('Enter saves the text and its look, Esc cancels',
        (tester) async {
      final (saved, cancels) = await pump(tester);
      await tester.enterText(find.byType(TextField), 'Shine bright');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(saved.single.$1, 'Shine bright');
      // "Shine" kept its bold through the edit
      expect(saved.single.$2.spans.single.bold, true);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(cancels, [1]);
    });

    testWidgets('Shift+Enter is a new line, not a save', (tester) async {
      final (saved, _) = await pump(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(saved, isEmpty);
    });

    testWidgets('the Done button works for a mouse or a finger',
        (tester) async {
      final (saved, _) = await pump(tester);
      // Widget tests run as a phone, where the button just says Done
      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pump();
      expect(saved.single.$1, 'Shine shine shine');
    });
  });
}
