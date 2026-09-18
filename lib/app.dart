import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'engine/sync_engine.dart';
import 'models/script.dart';
import 'models/setlist_models.dart';
import 'models/song_settings.dart';
import 'models/song_theme.dart';
import 'services/file_service.dart';
import 'services/script_parser.dart';
import 'services/settings_service.dart';
import 'services/song_settings_store.dart';
import 'views/home_view.dart';
import 'views/editor_view.dart';
import 'views/teleprompter_view.dart';
import 'views/settings_view.dart';
import 'utils/app_platform.dart';
import 'utils/app_theme.dart';
import 'utils/back_dispatcher.dart';
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
  SettingsSection _settingsSection = SettingsSection.display;
  bool _applyingSongSpeed = false;

  // Where each song was left mid-way, so an accidental Esc / next / previous
  // doesn't lose your place. Only recent: a song stopped in this afternoon's
  // rehearsal still starts from the top at the show.
  final Map<String, (int, DateTime)> _leftMidSong = {};
  static const _resumeWithin = Duration(minutes: 5);

  bool _launchedFromHome = false;
  List<SetlistEntry> _setlist = [];
  int _setlistIndex = 0;

  List<SetlistEntry> _editorSetlist = [];
  int _editorSetlistIndex = 0;

  final SyncEngine _syncEngine = SyncEngine();
  final FileService _fileService = FileService();
  final BackDispatcher _back = BackDispatcher();

  @override
  void initState() {
    super.initState();
    if (AppPlatform.isDesktop) windowManager.addListener(this);
    _syncEngine.addListener(_onSyncEngineChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    if (AppPlatform.isDesktop) windowManager.removeListener(this);
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

  // Colours picked from the song's own menu are saved for that song too
  void _setSongTheme(SongTheme theme) => _onSongSettingsChanged(
      _activeSongSettings.copyWith(colorTheme: theme.code));

  void _resetSongTheme() =>
      _saveSongSettings(_songSettings.withColorTheme(null));

  void _resetSongSettings() {
    _saveSongSettings(SongSettings.none);
    _applySongSpeed(_settings.scrollSpeedMultiplier);
  }

  void _openSettings([SettingsSection section = SettingsSection.display]) {
    setState(() {
      _settingsSection = section;
      _showSettings = true;
    });
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

  // Editing mid-show keeps the setlist, so Launch brings the song back with
  // Next and Previous still working
  void _editFromTeleprompter() {
    _syncEngine.stop();
    setState(() {
      _editorSetlist = _setlist;
      _editorSetlistIndex = _setlistIndex;
      _screen = AppScreen.editor;
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
      theme: buildAppTheme(),
      // Messages and dialogs sized to the screen, so they fit a phone too
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            snackBarTheme: theme.snackBarTheme.copyWith(
              width: width < 600 ? width - 24 : 560,
            ),
            dialogTheme: theme.dialogTheme.copyWith(
              insetPadding: EdgeInsets.symmetric(
                horizontal: width < 600 ? 16 : 40,
                vertical: 24,
              ),
            ),
          ),
          child: child!,
        );
      },
      home: PopScope(
        // Android's back gesture: closes Settings, leaves the editor or a
        // song through their own handlers, and only exits from home
        canPop: _screen == AppScreen.home && !_showSettings,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_showSettings) {
            setState(() => _showSettings = false);
          } else {
            _back.handle();
          }
        },
        child: Stack(
          children: [
            Column(
              children: [
                if (AppPlatform.isDesktop && _screen != AppScreen.teleprompter)
                  const WindowTitleBar(),
                Expanded(
                  // The song screen is full screen; other screens keep clear
                  // of the status bar, camera cutout and gesture bar
                  child: SafeArea(
                    top: _screen != AppScreen.teleprompter,
                    bottom: _screen != AppScreen.teleprompter,
                    left: _screen != AppScreen.teleprompter,
                    right: _screen != AppScreen.teleprompter,
                    child: _buildCurrentScreen(),
                  ),
                ),
              ],
            ),
            if (_showSettings) _buildSettingsOverlay(),
          ],
        ),
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
          onOpenSettings: _openSettings,
          onOpenShortcuts: () => _openSettings(SettingsSection.shortcuts),
          onSettingsRestored: _loadSettings,
        );
      case AppScreen.editor:
        return EditorView(
          initialScript: _activeScript,
          onLaunchTeleprompter: _launchTeleprompter,
          onBack: _backToHome,
          isLibrarySong: _editorSetlist.isNotEmpty,
          backDispatcher: _back,
        );
      case AppScreen.teleprompter:
        return TeleprompterView(
          key: ValueKey(_activeScript.title + _setlistIndex.toString()),
          script: _activeScript,
          syncEngine: _syncEngine,
          settings: _activeSongSettings,
          onBack: _backFromTeleprompter,
          onSettings: _openSettings,
          onNextScript: _hasNextScript ? _nextScript : null,
          onPrevScript: _hasPrevScript ? _prevScript : null,
          resumeAtLine: _resumeLineFor(_activeScript.title),
          onLeave: _rememberWhereLeft,
          defaultTheme: _settings.songTheme,
          songHasOwnTheme: _songSettings.colorTheme != null,
          onThemeChanged: _setSongTheme,
          onThemeReset: _resetSongTheme,
          backDispatcher: _back,
          onEdit: _editFromTeleprompter,
          onScriptChanged: (script) => _activeScript = script,
          setlistPosition: _launchedFromHome
              ? '${_setlistIndex + 1} / ${_setlist.length}'
              : null,
        );
    }
  }

  int? _resumeLineFor(String songTitle) {
    final left = _leftMidSong[songTitle];
    if (left == null) return null;
    final (line, at) = left;
    return DateTime.now().difference(at) < _resumeWithin ? line : null;
  }

  // Called while the song's view is being disposed, so no setState here
  void _rememberWhereLeft(String songTitle, int? line) {
    if (line == null) {
      _leftMidSong.remove(songTitle);
    } else {
      _leftMidSong[songTitle] = (line, DateTime.now());
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
          color: const Color(0xB3000000),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            // On a phone the panel fills the screen, clear of the system bars
            child: SettingsView(
              settings: onSong ? _activeSongSettings : _settings,
              songTitle: onSong ? _activeScript.title : null,
              songHasOwnSettings: onSong && !_songSettings.isEmpty,
              onChanged:
                  onSong ? _onSongSettingsChanged : _onDefaultSettingsChanged,
              onResetSong: _resetSongSettings,
              onClose: () => setState(() => _showSettings = false),
              initialSection: _settingsSection,
            ),
          ),
        ),
      ),
    );
  }
}
