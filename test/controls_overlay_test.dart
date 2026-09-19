import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/engine/scroll_engine.dart';
import 'package:music_teleprompter/engine/sync_engine.dart';
import 'package:music_teleprompter/widgets/controls_overlay.dart';

void main() {
  // The default test font draws every glyph 1em wide; use the real one.
  setUpAll(() async {
    final loader = FontLoader('TeleprompterMono');
    for (final file in ['JetBrainsMono-Regular.ttf', 'JetBrainsMono-Bold.ttf']) {
      final bytes = await File('assets/fonts/$file').readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  late SyncEngine sync;
  late List<String> calls;

  Future<void> pumpOverlay(WidgetTester tester,
      {double width = 800, String? timingLabel}) async {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    sync = SyncEngine();
    calls = [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ControlsOverlay(
          syncEngine: sync,
          scrollEngine: ScrollEngine(syncEngine: sync),
          onPlayPause: () => calls.add('playPause'),
          onFullscreen: () {},
          onSettings: () {},
          onEdit: () {},
          onBack: () {},
          onNextScript: () => calls.add('nextSong'),
          onPrevScript: () {},
          onToggleMirror: () {},
          onTapTempo: () {},
          onSetDuration: () {},
          onUnloadAudio: () {},
          timingLabel: timingLabel,
          onRecordTiming: () => calls.add('recordTiming'),
          onRemoveTiming:
              timingLabel == null ? null : () => calls.add('removeTiming'),
          setlistPosition: '12 / 20',
          isFullscreen: false,
          isMirrored: false,
          songTitle: 'If I Never See Your Face Again — Maroon 5 feat. Rihanna',
          hasAudio: true,
          audioVolume: 0.8,
          onVolumeChanged: (_) {},
          hasChords: true,
          onTransposeChanged: (_) {},
          onToggleCueMode: () {},
          remoteUrl: 'http://192.168.1.20:8765',
          onThemeChanged: (_) {},
          onMoveToDisplay: () {},
        ),
      ),
    ));
  }

  // Disposes the overlay so its auto-hide timer doesn't outlive the test
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  testWidgets('every control fits the smallest window, all features on',
      (tester) async {
    await pumpOverlay(tester, width: 800, timingLabel: 'Rehearsal timing');
    // A layout overflow would already have failed the test
    for (final tooltip in ['Back (Esc)', 'More', 'Settings', 'Fullscreen (F)']) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
    }
    await unmount(tester);
  });

  testWidgets('play button uses the same start logic as Space', (tester) async {
    await pumpOverlay(tester);
    await tester.tap(find.byTooltip('Play (Space)'));
    expect(calls, ['playPause']);
    await unmount(tester);
  });

  testWidgets('speed buttons step by 0.05 exactly', (tester) async {
    await pumpOverlay(tester, width: 1280);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Speed up (+)'));
    }
    await tester.pump();
    expect(sync.state.manualMultiplier, 1.15);
    expect(find.text('1.15×'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('More menu holds the other tools', (tester) async {
    await pumpOverlay(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    for (final label in [
      'Record timing…',
      'Tap tempo…',
      'Set song duration…',
      'Transpose…',
      'Mirror text',
      'Colour theme…',
      'Edit lyrics…',
      'Phone remote…',
      'Move to second display',
      'Remove backing track…',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Remove timing…'), findsNothing);
    await tester.tap(find.text('Record timing…'));
    await tester.pumpAndSettle();
    expect(calls, ['recordTiming']);
    await unmount(tester);
  });

  testWidgets('a timed song shows its clock instead of speed controls',
      (tester) async {
    await pumpOverlay(tester, width: 1280, timingLabel: 'Rehearsal timing');
    expect(find.text('TIMED'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.byTooltip('Speed up (+)'), findsNothing);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Record timing again…'), findsOneWidget);
    expect(find.text('Remove timing…'), findsOneWidget);
    expect(find.text('Tap tempo…'), findsNothing,
        reason: 'speed tools do nothing for a timed song');
    await unmount(tester);
  });

  testWidgets('removing timing asks first', (tester) async {
    await pumpOverlay(tester, timingLabel: 'Online synced timing');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove timing…'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove timing…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(calls, ['removeTiming']);
    await unmount(tester);
  });

  testWidgets('hidden controls ignore taps, so NEXT can\'t be hit by accident',
      (tester) async {
    await pumpOverlay(tester, width: 1280);
    sync.play(); // controls only auto-hide while playing
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('NEXT'), warnIfMissed: false);
    expect(calls, isEmpty);

    // That tap brought the controls back; now NEXT works
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT'));
    expect(calls, ['nextSong']);
    await unmount(tester);
  });
}
