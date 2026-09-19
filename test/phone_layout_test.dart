import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/engine/scroll_engine.dart';
import 'package:music_teleprompter/engine/sync_engine.dart';
import 'package:music_teleprompter/services/script_parser.dart';
import 'package:music_teleprompter/services/settings_service.dart';
import 'package:music_teleprompter/utils/app_theme.dart';
import 'package:music_teleprompter/views/settings_view.dart';
import 'package:music_teleprompter/widgets/controls_overlay.dart';
import 'package:music_teleprompter/widgets/timing_recorder.dart';

/// Phone screens are far narrower than any desktop window, so every screen
/// gets checked at the size of a small phone. An overflow fails the test.
/// Widget tests already run as Android, so the touch layouts are the ones
/// being built here.
void main() {
  const phone = Size(360, 780);

  setUpAll(() async {
    // The default test font draws every glyph 1em wide, which makes text far
    // wider than it really is; load the fonts the app ships with
    for (final entry in const {
      'TeleprompterMono': ['JetBrainsMono-Regular.ttf', 'JetBrainsMono-Bold.ttf'],
      'AppSans': ['Manrope-Regular.ttf', 'Manrope-SemiBold.ttf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        final bytes = await File('assets/fonts/$file').readAsBytes();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
  });

  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: child),
    ));
  }

  testWidgets('Settings fills a phone screen and switches tabs',
      (tester) async {
    await pumpPhone(
      tester,
      SettingsView(
        settings: const AppSettings(),
        onChanged: (_) {},
        onResetSong: () {},
        onClose: () {},
      ),
    );

    // Tabs across the top instead of the desktop side column
    expect(find.text('Display'), findsWidgets);
    expect(find.text('Colour Theme'), findsOneWidget);

    await tester.tap(find.text('Controls'));
    await tester.pumpAndSettle();
    expect(find.text('Foot Pedal — Forward Action'), findsOneWidget);
  });

  testWidgets('the song controls fit, with loop under More', (tester) async {
    final sync = SyncEngine();
    final scroll = ScrollEngine(syncEngine: sync);
    addTearDown(scroll.dispose);

    await pumpPhone(
      tester,
      ControlsOverlay(
        syncEngine: sync,
        scrollEngine: scroll,
        onPlayPause: () {},
        onFullscreen: null, // a phone is always full screen
        onSettings: () {},
        onEdit: () {},
        onBack: () {},
        onToggleMirror: () {},
        onTapTempo: () {},
        onSetDuration: () {},
        onUnloadAudio: () {},
        onRecordTiming: () {},
        isFullscreen: false,
        isMirrored: false,
        songTitle: 'If I Never See Your Face Again — Maroon 5 feat. Rihanna',
        hasAudio: false,
        audioVolume: 0.8,
        onVolumeChanged: (_) {},
        hasChords: false,
        onTransposeChanged: (_) {},
        onToggleCueMode: () {},
      ),
    );

    expect(find.byTooltip('Fullscreen (F)'), findsNothing);
    expect(find.byTooltip('Loop section (L)'), findsNothing);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Loop section'), findsOneWidget);
    // Key hints belong to a keyboard, not a phone
    expect(find.text('T'), findsNothing);

    await tester.tapAt(const Offset(10, 10)); // close the menu
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox()); // stop the auto-hide timer
  });

  testWidgets('recording timing: tapping the screen times each line',
      (tester) async {
    final script = ScriptParser.parse('[Verse 1]\nLine one\nLine two\nLine three');
    final sync = SyncEngine();
    final scroll = ScrollEngine(syncEngine: sync);
    scroll.setScript(script, 100);
    addTearDown(scroll.dispose);
    List<(int, Duration)>? saved;

    final key = GlobalKey<TimingRecorderState>();
    await pumpPhone(
      tester,
      Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => key.currentState?.tap(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: TimingRecorder(
              key: key,
              script: script,
              scrollEngine: scroll,
              replacesTiming: false,
              onSave: (times) => saved = times,
              onCancel: () {},
            ),
          ),
        ],
      ),
    );

    expect(find.textContaining('tap the screen'), findsOneWidget);

    // Tapping low on the screen, clear of the banner, times the lines
    await tester.tapAt(const Offset(180, 600));
    await tester.pump();
    await tester.tapAt(const Offset(180, 600));
    await tester.pump();
    await tester.tapAt(const Offset(180, 600));
    await tester.pump();
    expect(find.text('Line 3 of 3'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(saved, isNotNull);
    expect(saved!.length, 2);
  });
}
