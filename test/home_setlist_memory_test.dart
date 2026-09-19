import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/utils/app_theme.dart';
import 'package:music_teleprompter/views/home_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The home screen comes back to the setlist that was open, not the first
/// one, after a show or the editor (it's rebuilt then) and after a restart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory appDir;

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
    appDir = await Directory.systemTemp.createTemp('teleprompter_home_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => appDir.path,
    );
    SharedPreferences.setMockInitialValues({});
    final scripts = Directory('${appDir.path}/scripts');
    await scripts.create(recursive: true);
    await File('${scripts.path}/setlists.json').writeAsString(jsonEncode([
      {'id': '1', 'name': 'Friday', 'items': []},
      {'id': '2', 'name': 'Saturday', 'items': []},
    ]));
  });

  tearDown(() => appDir.delete(recursive: true));

  Future<void> pumpHome(WidgetTester tester, {int epoch = 0}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: HomeView(
        key: ValueKey(epoch),
        onOpenScript: (_) {},
        onLaunchScript: (_, _, _) {},
        onOpenScriptWithSetlist: (_, _, _) {},
        onOpenSettings: () {},
        onOpenShortcuts: () {},
        onSettingsRestored: () {},
      ),
    ));
    // Setlists come from disk
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
  }

  testWidgets('the setlist that was open is the one that comes back',
      (tester) => tester.runAsync(() async {
    await pumpHome(tester);
    expect(find.text('FRIDAY'), findsOneWidget);

    await tester.tap(find.text('Saturday'));
    await tester.pump();
    expect(find.text('SATURDAY'), findsOneWidget);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // Home is rebuilt from scratch after a show or the editor
    await pumpHome(tester, epoch: 1);
    expect(find.text('SATURDAY'), findsOneWidget);
    expect(find.text('FRIDAY'), findsNothing);

    // …and it's remembered across a restart
    expect((await SharedPreferences.getInstance()).getString('last_setlist'),
        '2');
  }));
}
