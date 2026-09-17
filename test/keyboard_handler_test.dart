import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/engine/scroll_engine.dart';
import 'package:music_teleprompter/engine/sync_engine.dart';
import 'package:music_teleprompter/utils/keyboard_handler.dart';

void main() {
  group('Foot pedal', () {
    late List<String> calls;

    Future<void> pumpHandler(WidgetTester tester, String pedalAction) async {
      calls = [];
      final sync = SyncEngine();
      await tester.pumpWidget(MaterialApp(
        home: TeleprompterKeyboardHandler(
          syncEngine: sync,
          scrollEngine: ScrollEngine(syncEngine: sync),
          onToggleFullscreen: () {},
          onBack: () {},
          onNextScript: () => calls.add('nextSong'),
          onPrevScript: () => calls.add('prevSong'),
          onPlayPauseOverride: () => calls.add('playPause'),
          onJumpNextSection: () => calls.add('nextSection'),
          onJumpPrevSection: () => calls.add('prevSection'),
          pedalAction: pedalAction,
          child: const SizedBox.expand(),
        ),
      ));
      await tester.pump();
    }

    Future<void> pressPedals(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    }

    testWidgets('Next Section moves between sections', (tester) async {
      await pumpHandler(tester, 'nextSection');
      await pressPedals(tester);
      expect(calls, ['nextSection', 'prevSection']);
    });

    testWidgets('Next Song moves between songs', (tester) async {
      await pumpHandler(tester, 'nextSong');
      await pressPedals(tester);
      expect(calls, ['nextSong', 'prevSong']);
    });

    testWidgets('Play / Pause toggles playback', (tester) async {
      await pumpHandler(tester, 'playPause');
      await pressPedals(tester);
      expect(calls, ['playPause', 'playPause']);
    });
  });
}
