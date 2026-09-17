import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/engine/scroll_engine.dart';
import 'package:music_teleprompter/engine/sync_engine.dart';
import 'package:music_teleprompter/services/lrc_service.dart';
import 'package:music_teleprompter/services/script_parser.dart';

void main() {
  const lineHeight = 100.0;
  late SyncEngine sync;
  late ScrollEngine scroll;

  // "[Verse 1]" header on line 0, lyrics on lines 1–4
  final script = ScriptParser.parse(
      '[Verse 1]\nFirst line\nSecond line\nThird line\nFourth line');

  Future<void> setUpEngine(WidgetTester tester) async {
    sync = SyncEngine();
    scroll = ScrollEngine(syncEngine: sync)
      ..attach(const TestVSync())
      ..setScript(script, lineHeight)
      ..setTimeline(const [
        (1, Duration(seconds: 2)),
        (2, Duration(seconds: 4)),
        (3, Duration(seconds: 6)),
        (4, Duration(seconds: 8)),
      ])
      ..start();
    await tester.pump(); // first frame starts the ticker clock
  }

  // Runs the song clock forward in small frames
  Future<void> playFor(WidgetTester tester, Duration duration) async {
    const frame = Duration(milliseconds: 50);
    for (var t = Duration.zero; t < duration; t += frame) {
      await tester.pump(frame);
    }
  }

  testWidgets('a timed song scrolls without a backing track', (tester) async {
    await setUpEngine(tester);
    expect(scroll.isTimed, true);
    sync.play();
    await playFor(tester, const Duration(milliseconds: 4050));
    expect(scroll.clockSeconds, closeTo(4.0, 0.1));
    expect(scroll.activeLineIndex, 2);
    scroll.dispose(); // stops its ticker before the test ends
  });

  testWidgets('a line lights up when its time comes, not before',
      (tester) async {
    await setUpEngine(tester);
    sync.play();
    await playFor(tester, const Duration(milliseconds: 3900));
    expect(scroll.activeLineIndex, 1);
    // The scroll is already moving smoothly toward line 2
    expect(scroll.pixelOffset, greaterThan(1.5 * lineHeight));
    scroll.dispose(); // stops its ticker before the test ends
  });

  testWidgets('moving to a line re-syncs the song clock to it',
      (tester) async {
    await setUpEngine(tester);
    sync.play();
    await playFor(tester, const Duration(seconds: 1));
    scroll.scrollByLines(3); // the band is ahead: jump to where they are
    expect(scroll.activeLineIndex, 3);
    expect(scroll.clockSeconds, closeTo(6.0, 0.001));
    await playFor(tester, const Duration(milliseconds: 2050));
    expect(scroll.activeLineIndex, 4); // and it carries on from there
    scroll.dispose(); // stops its ticker before the test ends
  });

  testWidgets('pausing stops the song clock', (tester) async {
    await setUpEngine(tester);
    sync.play();
    await playFor(tester, const Duration(seconds: 3));
    sync.pause();
    final paused = scroll.clockSeconds;
    await playFor(tester, const Duration(seconds: 2));
    expect(scroll.clockSeconds, paused);
    scroll.dispose(); // stops its ticker before the test ends
  });

  testWidgets('the song ends a line\'s length after the last line',
      (tester) async {
    await setUpEngine(tester);
    var ended = 0;
    scroll.onEndReached = () => ended++;
    sync.play();
    await playFor(tester, const Duration(seconds: 9));
    expect(ended, 0, reason: 'the last line (8s) is still being sung');
    await playFor(tester, const Duration(seconds: 3));
    expect(ended, 1);
    scroll.dispose(); // stops its ticker before the test ends
  });

  testWidgets('clearing the timing goes back to scrolling at speed',
      (tester) async {
    await setUpEngine(tester);
    scroll.clearTimeline();
    expect(scroll.isTimed, false);
    sync.play();
    await playFor(tester, const Duration(seconds: 1));
    expect(scroll.pixelOffset, greaterThan(0));
    scroll.dispose(); // stops its ticker before the test ends
  });

  test('recorded timing round-trips through LRC', () {
    final lrc = LrcService.toLrc(const [
      ('First line', Duration(milliseconds: 2340)),
      ('Second line', Duration(minutes: 1, seconds: 5, milliseconds: 70)),
    ], rehearsal: true);
    expect(LrcService.isRehearsalTiming(lrc), true);
    final lines = LrcService.parse(lrc);
    expect(lines.map((l) => l.text), ['First line', 'Second line']);
    expect(lines[0].timestamp, const Duration(milliseconds: 2340));
    expect(lines[1].timestamp,
        const Duration(minutes: 1, seconds: 5, milliseconds: 70));
    // Matched to lyric lines, skipping the section header
    expect(LrcService.matchToScript(lines, script).map((m) => m.$1), [1, 2]);
  });
}
