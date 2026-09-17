import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'engine/sync_engine.dart';
import 'models/script.dart';
import 'models/setlist_models.dart';
import 'models/song_settings.dart';
import 'services/file_service.dart';
import 'services/script_parser.dart';
import 'services/settings_service.dart';
import 'services/song_settings_store.dart';
import 'views/home_view.dart';
import 'views/editor_view.dart';
import 'views/teleprompter_view.dart';
import 'views/settings_view.dart';
import 'utils/constants.dart';
import 'widgets/window_title_bar.dart';

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
  AppSettings _settings = const AppSettings(); // defaults for every song
  SongSettings _songSettings = SongSettings.none; // the active song's own
  bool _showSettings = false;
  bool _applyingSongSpeed = false;

  bool _launchedFromHome = false;
  List<SetlistEntry> _setlist = [];
  int _setlistIndex = 0;

  List<SetlistEntry> _editorSetlist = [];
  int _editorSetlistIndex = 0;

  final SyncEngine _syncEngine = SyncEngine();
  final FileService _fileService = FileService();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncEngine.addListener(_onSyncEngineChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _syncEngine.removeListener(_onSyncEngineChanged);
    _syncEngine.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService().load();
    setState(() => _settings = settings);
    _syncEngine.setManualMultiplier(settings.scrollSpeedMultiplier);
  }

  // ── Per-song settings ─────────────────────────────────────────────────────

  AppSettings get _activeSongSettings => _songSettings.applyTo(_settings);

  /// Loads a song's own settings and switches the scroll speed to it.
  Future<SongSettings> _songSettingsFor(String songTitle) async {
    final songSettings = await SongSettingsStore.getSettings(songTitle);
    _applySongSpeed(songSettings.applyTo(_settings).scrollSpeedMultiplier);
    return songSettings;
  }

  void _applySongSpeed(double speed) {
    _applyingSongSpeed = true;
    _syncEngine.setManualMultiplier(speed);
    _applyingSongSpeed = false;
  }

  // Speed changes made while a song is on screen (keys, slider, tap tempo,
  // phone remote) are saved for that song.
  void _onSyncEngineChanged() {
    if (_applyingSongSpeed || _screen != AppScreen.teleprompter) return;
    final speed = _syncEngine.state.manualMultiplier;
    if (speed == _activeSongSettings.scrollSpeedMultiplier) return;
    _saveSongSettings(_songSettings.withSpeed(speed));
  }

  void _saveSongSettings(SongSettings songSettings) {
    setState(() => _songSettings = songSettings);
    SongSettingsStore.saveSettings(_activeScript.title, songSettings);
  }

  void _onDefaultSettingsChanged(AppSettings updated) {
    setState(() => _settings = updated);
    SettingsService().save(updated);
  }

  // Auto-advance and the foot pedal stay the same for every song.
  void _onSongSettingsChanged(AppSettings updated) {
    if (updated.autoAdvance != _settings.autoAdvance ||
        updated.pedalAction != _settings.pedalAction) {
      _onDefaultSettingsChanged(_settings.copyWith(
        autoAdvance: updated.autoAdvance,
        pedalAction: updated.pedalAction,
      ));
    }
    _saveSongSettings(_songSettings.withChanges(_activeSongSettings, updated));
    _applySongSpeed(updated.scrollSpeedMultiplier);
  }

  void _resetSongSettings() {
    _saveSongSettings(SongSettings.none);
    _applySongSpeed(_settings.scrollSpeedMultiplier);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openScript(Script script) {
    setState(() {
      _activeScript = script;
      _editorSetlist = [];
      _editorSetlistIndex = 0;
      _screen = AppScreen.editor;
    });
  }

  void _openScriptWithSetlist(
      Script script, List<SetlistEntry> setlist, int index) {
    setState(() {
      _activeScript = script;
      _editorSetlist = setlist;
      _editorSetlistIndex = index;
      _screen = AppScreen.editor;
    });
  }

  Future<void> _launchTeleprompter(Script script) async {
    final songSettings = await _songSettingsFor(script.title);
    if (!mounted) return;
    if (_editorSetlist.isNotEmpty) {
      setState(() {
        _activeScript = script;
        _songSettings = songSettings;
        _setlist = _editorSetlist;
        _setlistIndex = _editorSetlistIndex;
        _launchedFromHome = true;
        _screen = AppScreen.teleprompter;
      });
    } else {
      setState(() {
        _activeScript = script;
        _songSettings = songSettings;
        _launchedFromHome = false;
        _setlist = [];
        _setlistIndex = 0;
        _screen = AppScreen.teleprompter;
      });
    }
  }

  Future<void> _launchScriptDirect(
      Script script, List<SetlistEntry> setlist, int index) async {
    final songSettings = await _songSettingsFor(script.title);
    if (!mounted) return;
    setState(() {
      _activeScript = script;
      _songSettings = songSettings;
      _setlist = setlist;
      _setlistIndex = index;
      _launchedFromHome = true;
      _screen = AppScreen.teleprompter;
    });
  }

  int _homeEpoch = 0;

  void _backToHome() {
    setState(() {
      _screen = AppScreen.home;
      _homeEpoch++;
      _editorSetlist = [];
      _editorSetlistIndex = 0;
    });
  }

  void _backFromTeleprompter() {
    _syncEngine.stop();
    setState(() {
      _screen =
          _launchedFromHome ? AppScreen.home : AppScreen.editor;
      if (_launchedFromHome) {
        _launchedFromHome = false;
        _setlist = [];
        _setlistIndex = 0;
      }
    });
  }

  bool get _hasNextScript =>
      _launchedFromHome && _setlistIndex < _setlist.length - 1;

  bool get _hasPrevScript =>
      _launchedFromHome && _setlistIndex > 0;

  Future<void> _nextScript() async {
    if (!_hasNextScript) return;
    final next = _setlist[_setlistIndex + 1];
    final content = await _fileService.readSavedScript(next.path);
    if (content == null || !mounted) return;
    final script = ScriptParser.parse(content, title: next.title);
    final songSettings = await _songSettingsFor(script.title);
    if (!mounted) return;
    setState(() {
      _activeScript = script;
      _songSettings = songSettings;
      _setlistIndex++;
    });
  }

  Future<void> _prevScript() async {
    if (!_hasPrevScript) return;
    final prev = _setlist[_setlistIndex - 1];
    final content = await _fileService.readSavedScript(prev.path);
    if (content == null || !mounted) return;
    final script = ScriptParser.parse(content, title: prev.title);
    final songSettings = await _songSettingsFor(script.title);
    if (!mounted) return;
    setState(() {
      _activeScript = script;
      _songSettings = songSettings;
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
          Column(
            children: [
              if (_screen != AppScreen.teleprompter) const WindowTitleBar(),
              Expanded(child: _buildCurrentScreen()),
            ],
          ),
          if (_showSettings) _buildSettingsOverlay(),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_screen) {
      case AppScreen.home:
        return HomeView(
          key: ValueKey(_homeEpoch),
          onOpenScript: _openScript,
          onLaunchScript: _launchScriptDirect,
          onOpenScriptWithSetlist: _openScriptWithSetlist,
          onOpenSettings: () => setState(() => _showSettings = true),
        );
      case AppScreen.editor:
        return EditorView(
          initialScript: _activeScript,
          onLaunchTeleprompter: _launchTeleprompter,
          onBack: _backToHome,
        );
      case AppScreen.teleprompter:
        return TeleprompterView(
          key: ValueKey(_activeScript.title + _setlistIndex.toString()),
          script: _activeScript,
          syncEngine: _syncEngine,
          settings: _activeSongSettings,
          onBack: _backFromTeleprompter,
          onSettings: () => setState(() => _showSettings = true),
          onNextScript: _hasNextScript ? _nextScript : null,
          onPrevScript: _hasPrevScript ? _prevScript : null,
          setlistPosition: _launchedFromHome
              ? '${_setlistIndex + 1} / ${_setlist.length}'
              : null,
        );
    }
  }

  // Opened from a song, the panel edits that song's settings; from the home
  // screen it edits the defaults.
  Widget _buildSettingsOverlay() {
    final onSong = _screen == AppScreen.teleprompter;
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showSettings = false),
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: SettingsView(
              settings: onSong ? _activeSongSettings : _settings,
              songTitle: onSong ? _activeScript.title : null,
              songHasOwnSettings: onSong && !_songSettings.isEmpty,
              onChanged:
                  onSong ? _onSongSettingsChanged : _onDefaultSettingsChanged,
              onResetSong: _resetSongSettings,
              onClose: () => setState(() => _showSettings = false),
            ),
          ),
        ),
      ),
    );
  }
}
