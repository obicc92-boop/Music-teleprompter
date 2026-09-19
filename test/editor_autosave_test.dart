import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/services/script_parser.dart';
import 'package:music_teleprompter/utils/app_theme.dart';
import 'package:music_teleprompter/views/editor_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The editor has no Save button: words reach the library by themselves a
/// moment after they're typed, a new title renames the song, and leaving
/// never loses anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory appDir;
  late Directory scripts;

  setUpAll(() async {
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

  setUp(() async {
    appDir = await Directory.systemTemp.createTemp('teleprompter_autosave_');
    scripts = Directory('${appDir.path}/scripts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => appDir.path,
    );
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => appDir.delete(recursive: true));

  Future<void> pumpEditor(
    WidgetTester tester, {
    String text = '',
    String title = 'Untitled',
    bool library = false,
    void Function(String, String, String)? onRenamed,
    VoidCallback? onBack,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: EditorView(
        initialScript: ScriptParser.parse(text, title: title),
        onLaunchTeleprompter: (_) {},
        onBack: onBack ?? () {},
        isLibrarySong: library,
        onSongRenamed: onRenamed,
      ),
    ));
    await tester.pump();
  }

  // Saves run on real timers and real files, so the test waits real time
  Future<void> wait(WidgetTester tester, [int ms = 1400]) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    await tester.pump();
  }

  Finder lyricsField() => find.byWidgetPredicate(
        (w) => w is TextField && w.maxLines == null && w.expands,
      );
  Finder titleField() => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Song title',
      );

  testWidgets('words typed in a new song are saved a moment later',
      (tester) => tester.runAsync(() async {
    await pumpEditor(tester);
    expect(find.text('Saves as you type'), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await tester.enterText(lyricsField(), 'La la la');
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    expect(await File('${scripts.path}/Untitled.txt').exists(), false);

    await wait(tester);
    expect(await File('${scripts.path}/Untitled.txt').readAsString(),
        'La la la');
    expect(find.text('Saved'), findsOneWidget);
  }));

  testWidgets('a new title renames the saved song after a pause',
      (tester) => tester.runAsync(() async {
    final renames = <(String, String)>[];
    await pumpEditor(tester, onRenamed: (from, to, _) => renames.add((from, to)));
    await tester.enterText(lyricsField(), 'La la la');
    await wait(tester);
    expect(await File('${scripts.path}/Untitled.txt').exists(), true);

    await tester.enterText(titleField(), 'Lalala');
    await wait(tester, 1000);
    // Not yet: a title gets a longer pause, since it renames the song
    expect(await File('${scripts.path}/Lalala.txt').exists(), false);
    await wait(tester, 1500);
    expect(await File('${scripts.path}/Lalala.txt').readAsString(), 'La la la');
    expect(await File('${scripts.path}/Untitled.txt').exists(), false);
    expect(renames, [('Untitled', 'Lalala')]);
  }));

  testWidgets('leaving right after typing still saves',
      (tester) => tester.runAsync(() async {
    var left = false;
    await pumpEditor(
      tester,
      text: 'Old words',
      title: 'Song',
      library: true,
      onBack: () => left = true,
    );
    await tester.enterText(lyricsField(), 'New words');
    await tester.pump();
    await tester.tap(find.text('Home'));
    await wait(tester, 300);
    expect(left, true);
    expect(await File('${scripts.path}/Song.txt').readAsString(), 'New words');
  }));

  testWidgets('Revert puts the song back as it was opened',
      (tester) => tester.runAsync(() async {
    await File('${scripts.path}/Song.txt').create(recursive: true);
    await File('${scripts.path}/Song.txt').writeAsString('Old words');
    await pumpEditor(tester, text: 'Old words', title: 'Song', library: true);
    expect(find.text('Revert'), findsNothing);

    await tester.enterText(lyricsField(), 'New words');
    await wait(tester);
    expect(await File('${scripts.path}/Song.txt').readAsString(), 'New words');

    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    await wait(tester, 300);
    expect(await File('${scripts.path}/Song.txt').readAsString(), 'Old words');
    expect(find.text('Revert'), findsNothing);
    expect(find.text('Saved'), findsOneWidget);
  }));

  testWidgets('reverting a song that started blank removes it again',
      (tester) => tester.runAsync(() async {
    await pumpEditor(tester);
    await tester.enterText(lyricsField(), 'Oops');
    await wait(tester);
    expect(await File('${scripts.path}/Untitled.txt').exists(), true);

    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Throw away'));
    await tester.pumpAndSettle();
    await wait(tester, 300);
    expect(await File('${scripts.path}/Untitled.txt').exists(), false);
    expect(find.text('Saves as you type'), findsOneWidget);
  }));
}
