import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/engine/scroll_engine.dart';
import 'package:music_teleprompter/engine/sync_engine.dart';
import 'package:music_teleprompter/services/script_parser.dart';
import 'package:music_teleprompter/widgets/timing_recorder.dart';

void main() {
  // Header on line 0, lyrics on 1–2, blank line 3, header on 4, lyric on 5
  final script = ScriptParser.parse(
      '[Verse]\nFirst line\nSecond line\n\n[Chorus]\nBig line');

  late ScrollEngine scroll;
  List<(int, Duration)>? saved;
  var cancelled = 0;

  Future<void> pumpRecorder(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    scroll = ScrollEngine(syncEngine: SyncEngine())..setScript(script, 100);
    saved = null;
    cancelled = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: TimingRecorder(
            script: script,
            scrollEngine: scroll,
            replacesTiming: false,
            onSave: (times) => saved = times,
            onCancel: () => cancelled++,
          ),
        ),
      ),
    ));
    await tester.pump(); // focus arrives after the first frame
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump(const Duration(milliseconds: 20));
  }

  // The recorder's clock ticks every 250ms; unmounting stops it
  Future<void> finish(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('taps time each lyric line, skipping headers and blanks',
      (tester) async {
    await pumpRecorder(tester);
    expect(find.text('Record timing'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.space); // the song starts
    expect(find.text('Line 1 of 3'), findsOneWidget);
    expect(find.textContaining('First line'), findsOneWidget); // what's next

    await press(tester, LogicalKeyboardKey.space);
    expect(scroll.activeLineIndex, 1);
    await press(tester, LogicalKeyboardKey.pageDown); // foot pedal
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(scroll.activeLineIndex, 5);
    expect(find.text('All 3 lines timed'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.enter); // pedal saves when done
    expect(saved!.map((t) => t.$1), [1, 2, 5]);
    final times = saved!.map((t) => t.$2).toList();
    expect(times, orderedEquals([...times]..sort()));
    await finish(tester);
  });

  testWidgets('↑ takes back a mistimed tap', (tester) async {
    await pumpRecorder(tester);
    await press(tester, LogicalKeyboardKey.space);
    await press(tester, LogicalKeyboardKey.space);
    await press(tester, LogicalKeyboardKey.space); // too early
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(find.text('Line 2 of 3'), findsOneWidget);
    expect(scroll.activeLineIndex, 1);
    await finish(tester);
  });

  testWidgets('a partly timed song can be saved from two lines on',
      (tester) async {
    await pumpRecorder(tester);
    await press(tester, LogicalKeyboardKey.space);
    await press(tester, LogicalKeyboardKey.space);
    await tester.tap(find.text('Done'));
    expect(saved, isNull, reason: 'one line gives no pace to continue at');

    await press(tester, LogicalKeyboardKey.space);
    await tester.tap(find.text('Done'));
    expect(saved!.map((t) => t.$1), [1, 2]);
    await finish(tester);
  });

  testWidgets('Esc cancels straight away before much is recorded',
      (tester) async {
    await pumpRecorder(tester);
    await press(tester, LogicalKeyboardKey.space);
    await press(tester, LogicalKeyboardKey.escape);
    expect(cancelled, 1);
    await finish(tester);
  });

  testWidgets('Esc asks before discarding a longer recording', (tester) async {
    await pumpRecorder(tester);
    for (var i = 0; i < 4; i++) {
      await press(tester, LogicalKeyboardKey.space);
    }
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(cancelled, 0);
    expect(find.text('Discard this recording?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(cancelled, 1);
    await finish(tester);
  });

  testWidgets('keys that would lose the recording are ignored', (tester) async {
    await pumpRecorder(tester);
    await press(tester, LogicalKeyboardKey.space);
    await press(tester, LogicalKeyboardKey.space);
    final handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    expect(handled, true, reason: 'next song must not reach the teleprompter');
    await finish(tester);
  });
}
