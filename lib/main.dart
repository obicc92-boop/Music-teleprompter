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
      await windowManager.show();
      await windowManager.focus();
      // The whole screen from the start; the size above is the fallback
      // when the window is restored
      await windowManager.maximize();
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
}
