import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'engine/audio_engine.dart';
import 'engine/sync_engine.dart';
import 'engine/voice_profiler.dart';
import 'models/script.dart';
import 'services/file_service.dart';
import 'services/script_parser.dart';
import 'services/settings_service.dart';
import 'services/voice_profile_service.dart';
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

  // Setlist navigation state
  bool _launchedFromHome = false;
  List<SetlistEntry> _setlist = [];
  int _setlistIndex = 0;

  late final AudioEngine _audioEngine;
  late final SyncEngine _syncEngine;
  late final VoiceProfiler _voiceProfiler;
  final FileService _fileService = FileService();
  final VoiceProfileService _voiceProfileService = VoiceProfileService();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _audioEngine = AudioEngine(voiceSensitivity: _settings.voiceSensitivity);
    _syncEngine = SyncEngine(audioEngine: _audioEngine);
    _voiceProfiler = VoiceProfiler();
    _syncEngine.setVoiceProfiler(_voiceProfiler);
    _loadSettings();
    _loadVoiceProfile();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _syncEngine.dispose();
    _voiceProfiler.dispose();
    super.dispose();
  }

  Future<void> _loadVoiceProfile() async {
    final vector = await _voiceProfileService.load();
    if (vector != null) _voiceProfiler.loadProfile(vector);
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

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openScript(Script script) {
    setState(() {
      _activeScript = script;
      _screen = AppScreen.editor;
    });
  }

  void _launchTeleprompter(Script script) {
    setState(() {
      _activeScript = script;
      _launchedFromHome = false;
      _setlist = [];
      _setlistIndex = 0;
      _screen = AppScreen.teleprompter;
    });
  }

  void _launchScriptDirect(
    Script script,
    List<SetlistEntry> setlist,
    int index,
  ) {
    setState(() {
      _activeScript = script;
      _setlist = setlist;
      _setlistIndex = index;
      _launchedFromHome = true;
      _screen = AppScreen.teleprompter;
    });
  }

  void _backToHome() {
    setState(() => _screen = AppScreen.home);
  }

  void _backFromTeleprompter() {
    _syncEngine.stop();
    setState(() {
      _screen = _launchedFromHome ? AppScreen.home : AppScreen.editor;
      if (_launchedFromHome) {
        _launchedFromHome = false;
        _setlist = [];
        _setlistIndex = 0;
      }
    });
  }

  // ── Setlist next / prev ───────────────────────────────────────────────────

  bool get _hasNextScript =>
      _launchedFromHome && _setlistIndex < _setlist.length - 1;

  bool get _hasPrevScript => _launchedFromHome && _setlistIndex > 0;

  Future<void> _nextScript() async {
    if (!_hasNextScript) return;
    final next = _setlist[_setlistIndex + 1];
    final content = await _fileService.readSavedScript(next.path);
    if (content == null || !mounted) return;
    final script = ScriptParser.parse(content, title: next.title);
    setState(() {
      _activeScript = script;
      _setlistIndex++;
    });
  }

  Future<void> _prevScript() async {
    if (!_hasPrevScript) return;
    final prev = _setlist[_setlistIndex - 1];
    final content = await _fileService.readSavedScript(prev.path);
    if (content == null || !mounted) return;
    final script = ScriptParser.parse(content, title: prev.title);
    setState(() {
      _activeScript = script;
      _setlistIndex--;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
        return HomeView(
          onOpenScript: _openScript,
          onLaunchScript: _launchScriptDirect,
        );
      case AppScreen.editor:
        return EditorView(
          initialScript: _activeScript,
          onLaunchTeleprompter: _launchTeleprompter,
          onBack: _backToHome,
        );
      case AppScreen.teleprompter:
        return TeleprompterView(
          // Key forces a fresh state when the script changes mid-setlist
          key: ValueKey(_activeScript.title + _setlistIndex.toString()),
          script: _activeScript,
          syncEngine: _syncEngine,
          settings: _settings,
          onBack: _backFromTeleprompter,
          onSettings: () => setState(() => _showSettings = true),
          onNextScript: _hasNextScript ? () { _nextScript(); } : null,
          onPrevScript: _hasPrevScript ? () { _prevScript(); } : null,
          setlistPosition: _launchedFromHome
              ? '${_setlistIndex + 1} / ${_setlist.length}'
              : null,
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
              voiceProfiler: _voiceProfiler,
              voiceProfileService: _voiceProfileService,
              onChanged: (s) => setState(() => _settings = s),
              onClose: () => setState(() => _showSettings = false),
            ),
          ),
        ),
      ),
    );
  }
}
