import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'engine/audio_engine.dart';
import 'engine/sync_engine.dart';
import 'models/script.dart';
import 'services/settings_service.dart';
import 'views/home_view.dart';
import 'views/editor_view.dart';
import 'views/teleprompter_view.dart';
import 'views/settings_view.dart';
import 'utils/constants.dart';

enum AppScreen { home, editor, teleprompter }

class MusicTeleprompterApp extends ConsumerStatefulWidget {
  const MusicTeleprompterApp({super.key});

  @override
  ConsumerState<MusicTeleprompterApp> createState() =>
      _MusicTeleprompterAppState();
}

class _MusicTeleprompterAppState extends ConsumerState<MusicTeleprompterApp>
    with WindowListener {
  @override
  void onWindowClose() async {
    await _syncEngine.stop();
    await windowManager.destroy();
  }
  AppScreen _screen = AppScreen.home;
  Script _activeScript = Script.empty();
  AppSettings _settings = const AppSettings();
  bool _showSettings = false;

  late final AudioEngine _audioEngine;
  late final SyncEngine _syncEngine;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _audioEngine = AudioEngine(
      voiceSensitivity: _settings.voiceSensitivity,
    );
    _syncEngine = SyncEngine(audioEngine: _audioEngine);
    _loadSettings();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _syncEngine.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService().load();
    setState(() => _settings = settings);
    _syncEngine.updateVoiceSensitivity(settings.voiceSensitivity);
    _syncEngine.setUseManualBpm(settings.useManualBpm);
    if (settings.useManualBpm) {
      _syncEngine.setManualBpm(settings.manualBpmOverride);
    }
    _syncEngine.setAutoScrollOnVoice(settings.autoScrollOnVoice);
  }

  void _openScript(Script script) {
    setState(() {
      _activeScript = script;
      _screen = AppScreen.editor;
    });
  }

  void _launchTeleprompter(Script script) {
    setState(() {
      _activeScript = script;
      _screen = AppScreen.teleprompter;
    });
  }

  void _backToHome() {
    setState(() => _screen = AppScreen.home);
  }

  void _backToEditor() {
    _syncEngine.stop();
    setState(() => _screen = AppScreen.editor);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Teleprompter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
        fontFamily: AppTextStyles.fontFamily,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.activeLine),
        ),
      ),
      home: Stack(
        children: [
          _buildCurrentScreen(),
          if (_showSettings) _buildSettingsOverlay(),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_screen) {
      case AppScreen.home:
        return HomeView(onOpenScript: _openScript);
      case AppScreen.editor:
        return EditorView(
          initialScript: _activeScript,
          onLaunchTeleprompter: _launchTeleprompter,
          onBack: _backToHome,
        );
      case AppScreen.teleprompter:
        return TeleprompterView(
          script: _activeScript,
          syncEngine: _syncEngine,
          settings: _settings,
          onBack: _backToEditor,
          onSettings: () => setState(() => _showSettings = true),
        );
    }
  }

  Widget _buildSettingsOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showSettings = false),
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: SettingsView(
              settings: _settings,
              syncEngine: _syncEngine,
              onChanged: (s) => setState(() => _settings = s),
              onClose: () => setState(() => _showSettings = false),
            ),
          ),
        ),
      ),
    );
  }
}
