import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'utils/app_platform.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppPlatform.isDesktop) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(800, 600),
      center: true,
      title: 'Music Teleprompter',
      backgroundColor: Color(0xFF0A0A0A),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      // Closing goes through the app, so words typed a moment ago are
      // saved first (see onWindowClose)
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });
  } else {
    // Draw behind the status and navigation bars, which stay light-on-dark
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  runApp(
    const ProviderScope(
      child: MusicTeleprompterApp(),
    ),
  );

  // The whole screen from the start; the size above is what the window
  // goes back to when it's restored. The request is a posted message that
  // the window sometimes misses while it's still coming up, so it's asked
  // again until it took.
  if (AppPlatform.isDesktop) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _maximizeWhenReady());
  }
}

Future<void> _maximizeWhenReady() async {
  // Keeps nudging for the first few seconds: start-up work can still
  // restore the window after the first request took
  for (var tick = 0; tick < 12; tick++) {
    if (!await windowManager.isMaximized()) await windowManager.maximize();
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}
