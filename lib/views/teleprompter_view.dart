import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import '../engine/sync_engine.dart';
import '../engine/scroll_engine.dart';
import '../models/script.dart';
import '../models/script_formatting.dart';
import '../services/audio_service.dart';
import '../services/chord_transposer.dart';
import '../services/remote_control_server.dart';
import '../models/song_theme.dart';
import '../services/song_audio_store.dart';
import '../services/song_lrc_store.dart';
import '../services/song_lrc_content_store.dart';
import '../services/song_transpose_store.dart';
import '../services/lrc_service.dart';
import '../utils/constants.dart';
import '../utils/keyboard_handler.dart';
import '../widgets/controls_overlay.dart';
import '../widgets/format_overlay.dart';
import '../widgets/mirror_transform.dart';
import '../widgets/script_line_widget.dart';
import '../widgets/timing_recorder.dart';
import '../services/settings_service.dart';
import '../services/formatting_service.dart';

// Nobody touches the computer while singing, so without this the display
// dims or sleeps mid-song. Counted, because moving to the next song builds
// its view before the previous one is disposed.
class _ScreenAwake {
  static int _holders = 0;

  static void hold() {
    if (_holders++ == 0) _set(true);
  }

  static void release() {
    if (--_holders == 0) _set(false);
  }

  static void _set(bool awake) {
    unawaited(WakelockPlus.toggle(enable: awake).catchError((Object _) {}));
  }
}

class TeleprompterView extends StatefulWidget {
  final Script script;
  final SyncEngine syncEngine;
  final AppSettings settings;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback? onNextScript;
  final VoidCallback? onPrevScript;
  final String? setlistPosition;

  /// Line to pick up from, when this song was left mid-way a moment ago.
  final int? resumeAtLine;

  /// Reports where the song was left: its line if mid-song, otherwise null.
  final void Function(String songTitle, int? line)? onLeave;

  /// Colours every song uses unless it has its own, and this song's choice.
  final SongTheme defaultTheme;
  final bool songHasOwnTheme;
  final ValueChanged<SongTheme>? onThemeChanged;
  final VoidCallback? onThemeReset;

  const TeleprompterView({
    super.key,
    required this.script,
    required this.syncEngine,
    required this.settings,
    required this.onBack,
    required this.onSettings,
    this.onNextScript,
    this.onPrevScript,
    this.setlistPosition,
    this.resumeAtLine,
    this.onLeave,
    required this.defaultTheme,
    this.songHasOwnTheme = false,
    this.onThemeChanged,
    this.onThemeReset,
  });

  @override
  State<TeleprompterView> createState() => _TeleprompterViewState();
}

class _TeleprompterViewState extends State<TeleprompterView>
    with TickerProviderStateMixin {
  late final ScrollEngine _scrollEngine;
  late final AudioService _audioService;
  late final RemoteControlServer _remoteServer;
  String? _remoteUrl;
  late AppSettings _settings;
  late Script _script;
  ScriptFormatting _formatting = ScriptFormatting.empty;
  bool _isFullscreen = false;
  bool _showFormatOverlay = false;
  bool _isMirrored = false;
  bool _cueMode = false;
  // Song timing: where the lines' times come from (null = scrolls at speed)
  String? _timingLabel;
  bool _timingRemovable = false; // timing written in a lyrics file stays
  bool _recordingTiming = false;
  String? _notice; // short message at the top, e.g. "Press Esc again…"
  Timer? _noticeTimer;
  DateTime? _escapePressedAt;
  bool _initialized = false;
  final _keyboardFocus = FocusNode(debugLabel: 'TeleprompterKeys');
  int _transposeSteps = 0;
  int? _countdownValue;
  bool _isOnSecondDisplay = false;
  final List<DateTime> _tapTimes = [];

  final _formattingService = FormattingService();

  @override
  void initState() {
    super.initState();
    _ScreenAwake.hold();
    _settings = widget.settings;
    _script = widget.script;

    _audioService = AudioService();

    _scrollEngine = ScrollEngine(syncEngine: widget.syncEngine);
    _scrollEngine.attach(this);
    _scrollEngine.setScript(_script, _effectiveLineHeight);
    _scrollEngine.onSeek = _seekAudio;
    _syncEndReachedCallback();
    _scrollEngine.start();
    _applyScriptTimestamps();
    _resumeIfLeftMidSong();

    widget.syncEngine.addListener(_onSyncEngineChanged);

    _remoteServer = RemoteControlServer(onCommand: _onRemoteCommand);
    _remoteServer.start().then((url) {
      if (mounted) setState(() => _remoteUrl = url);
    });

    _loadFormatting();
    _loadSavedAudio();
    _loadSavedTranspose();
    _loadSavedTiming();
    _initialized = true;
  }

  Future<void> _loadFormatting() async {
    final fmt = await _formattingService.load(_script.title);
    if (mounted) setState(() => _formatting = fmt);
  }

  Future<void> _loadSavedAudio() async {
    final path = await SongAudioStore.getPath(_script.title);
    if (path == null || !mounted) return;
    final ok = await _audioService.loadFile(path);
    if (!ok) {
      // Saved path no longer valid — remove stale entry
      await SongAudioStore.removePath(_script.title);
    } else {
      // A timed song follows its backing track when it has one
      _scrollEngine.externalClock = () => _audioService.positionSeconds;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedTranspose() async {
    final steps = await SongTransposeStore.getTranspose(_script.title);
    if (mounted) setState(() => _transposeSteps = steps);
  }

  void _setTranspose(int steps) {
    final clamped = ((steps % 12) + 12) % 12;
    setState(() => _transposeSteps = clamped);
    SongTransposeStore.saveTranspose(_script.title, clamped);
  }

  SongTheme get _songTheme => _settings.songTheme;

  void _toggleCueMode() => setState(() => _cueMode = !_cueMode);

  // ── Countdown ─────────────────────────────────────────────────────────────

  Timer? _countdownTimer;

  void _onPlayPauseRequested() {
    // Cue mode: each press advances one line; no continuous scroll
    if (_cueMode) {
      _scrollEngine.scrollByLines(1);
      _syncAudioToScroll();
      return;
    }
    if (widget.syncEngine.isPlaying) {
      widget.syncEngine.togglePlayPause();
      return;
    }
    // If already counting down, cancel it (second tap = cancel)
    if (_countdownValue != null) {
      _countdownTimer?.cancel();
      setState(() => _countdownValue = null);
      return;
    }
    // Only show countdown when starting from scratch (stopped), not resuming
    if (widget.syncEngine.playState == PlayState.stopped) {
      _startCountdown();
    } else {
      widget.syncEngine.togglePlayPause();
    }
  }

  void _startCountdown() {
    setState(() => _countdownValue = 3);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = (_countdownValue ?? 0) - 1;
      if (next <= 0) {
        t.cancel();
        setState(() => _countdownValue = null);
        widget.syncEngine.play();
      } else {
        setState(() => _countdownValue = next);
      }
    });
  }

  @override
  void dispose() {
    final line = _scrollEngine.activeLineIndex;
    final midSong = line > 0 && line < _script.totalLines - 1;
    widget.onLeave?.call(_script.title, midSong ? line : null);
    _noticeTimer?.cancel();
    _keyboardFocus.dispose();
    _ScreenAwake.release();
    _countdownTimer?.cancel();
    _remoteServer.stop();
    widget.syncEngine.removeListener(_onSyncEngineChanged);
    _audioService.dispose();
    _scrollEngine.dispose();
    super.dispose();
  }

  Script get _displayScript =>
      ChordTransposer.transposeScript(_script, _transposeSteps);

  double get _effectiveLineHeight => _script.hasChordLines
      ? _settings.fontSize * 3.0
      : _settings.fontSize * 2.0;

  @override
  void didUpdateWidget(TeleprompterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings != oldWidget.settings) {
      setState(() => _settings = widget.settings);
      _scrollEngine.setLineHeight(_effectiveLineHeight);
      _syncEndReachedCallback();
    }
    if (widget.script != oldWidget.script) {
      // Song changed — reload audio for the new song
      _audioService.unload();
      setState(() => _script = widget.script);
      _loadSavedAudio();
    }
  }

  // ── SyncEngine → AudioService sync ────────────────────────────────────────

  void _onSyncEngineChanged() {
    if (!_audioService.isLoaded) return;
    switch (widget.syncEngine.playState) {
      case PlayState.playing:
        _audioService.play();
      case PlayState.paused:
        _audioService.pause();
      case PlayState.stopped:
        _audioService.stop();
    }
  }

  // ── Formatting / lyrics callbacks ──────────────────────────────────────────

  void _onFormattingChanged(ScriptFormatting fmt) {
    setState(() => _formatting = fmt);
    _formattingService.save(_script.title, fmt);
  }

  void _syncEndReachedCallback() {
    _scrollEngine.onEndReached =
        (_settings.autoAdvance && widget.onNextScript != null)
        ? () => Future.delayed(const Duration(seconds: 3), () {
            if (mounted) widget.onNextScript!();
          })
        : null;
  }

  // ── Fullscreen / back ──────────────────────────────────────────────────────

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    setState(() => _isFullscreen = next);
    await windowManager.setFullScreen(next);
  }

  bool get _hasSecondDisplay => PlatformDispatcher.instance.displays.length > 1;

  Future<void> _moveToSecondDisplay() async {
    if (_isOnSecondDisplay) {
      await windowManager.setFullScreen(false);
      await Future.delayed(const Duration(milliseconds: 150));
      await windowManager.setPosition(const Offset(100, 100));
      await windowManager.setSize(const Size(1280, 800));
      setState(() {
        _isOnSecondDisplay = false;
        _isFullscreen = false;
      });
    } else {
      final displays = PlatformDispatcher.instance.displays;
      if (displays.length < 2) return;
      final primary = displays.first;
      final logicalWidth = primary.size.width / primary.devicePixelRatio;
      await windowManager.setFullScreen(false);
      await Future.delayed(const Duration(milliseconds: 150));
      await windowManager.setPosition(Offset(logicalWidth + 50, 50));
      await Future.delayed(const Duration(milliseconds: 200));
      await windowManager.setFullScreen(true);
      setState(() {
        _isOnSecondDisplay = true;
        _isFullscreen = true;
      });
    }
  }

  // ── Keeping your place ─────────────────────────────────────────────────────

  void _resumeIfLeftMidSong() {
    final line = widget.resumeAtLine;
    if (line == null || line >= _script.totalLines) return;
    _scrollEngine.jumpToLine(line);
    final sections = _script.sections;
    final where = sections.isEmpty
        ? 'line ${line + 1}'
        : sections[_script.sectionIndexForLine(line)].label;
    _notice = 'Picked up where you left off — $where · R starts over';
    _noticeTimer = Timer(const Duration(seconds: 5), _clearNotice);
  }

  void _showNotice(String text, Duration duration) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(duration, _clearNotice);
  }

  void _clearNotice() {
    if (mounted) setState(() => _notice = null);
  }

  // While a song plays, Esc needs a second press, so a stray key can't stop
  // the show. The on-screen back button still leaves at once.
  void _handleEscape() {
    final playing = widget.syncEngine.isPlaying || _countdownValue != null;
    final pressedAt = _escapePressedAt;
    final pressedAgain =
        pressedAt != null &&
        DateTime.now().difference(pressedAt) < const Duration(seconds: 3);
    if (!playing || pressedAgain) {
      _handleBack();
      return;
    }
    _escapePressedAt = DateTime.now();
    _showNotice(
      'Press Esc again to leave this song',
      const Duration(seconds: 3),
    );
  }

  void _handleBack() {
    if (_isFullscreen) windowManager.setFullScreen(false);
    widget.syncEngine.stop();
    widget.onBack();
  }

  // ── Tap tempo ──────────────────────────────────────────────────────────────

  void _onTapTempo() {
    final now = DateTime.now();
    if (_tapTimes.isNotEmpty &&
        now.difference(_tapTimes.last).inMilliseconds > 3000) {
      _tapTimes.clear();
    }
    _tapTimes.add(now);
    if (_tapTimes.length > 8) _tapTimes.removeAt(0);
    if (_tapTimes.length < 2) return;

    final intervals = <double>[];
    for (int i = 1; i < _tapTimes.length; i++) {
      intervals.add(
        _tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds / 1000.0,
      );
    }
    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final multiplier = (0.5 / avgInterval).clamp(
      ScrollConstants.minSpeedMultiplier,
      ScrollConstants.maxSpeedMultiplier,
    );
    widget.syncEngine.setManualMultiplier(multiplier);
  }

  // ── Song duration → auto speed ─────────────────────────────────────────────

  void _onSetDuration() async {
    final result = await showDialog<Duration>(
      context: context,
      builder: (ctx) => const _DurationDialog(),
    );
    if (result == null || !mounted) return;
    _calibrateSpeedFromDuration(result);
  }

  void _calibrateSpeedFromDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) return;
    final totalPixels = (_script.allLines.length - 1) * _effectiveLineHeight;
    final speed = totalPixels / totalSeconds;
    final multiplier = (speed / ScrollConstants.pixelsPerSecondBase).clamp(
      ScrollConstants.minSpeedMultiplier,
      ScrollConstants.maxSpeedMultiplier,
    );
    widget.syncEngine.setManualMultiplier(multiplier);
  }

  // ── Audio ──────────────────────────────────────────────────────────────────

  Future<void> _onUnloadAudio() async {
    _scrollEngine.externalClock = null; // timing keeps running on its own clock
    _audioService.unload();
    await SongAudioStore.removePath(_script.title);
    setState(() {});
  }

  // ── Song timing ────────────────────────────────────────────────────────────
  // A timed song scrolls line by line at the moments it was timed: from a
  // rehearsal recording, from online synced lyrics, or from timestamps in the
  // lyrics file itself. No backing track is needed.

  // Timestamps written in the lyrics file itself ([mm:ss.xx] lines)
  void _applyScriptTimestamps() {
    final lines = _script.allLines;
    final timeline = [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].timestamp != null)
          (i, Duration(microseconds: (lines[i].timestamp! * 1e6).round())),
    ];
    _setTimeline(
      timeline,
      label: 'Timing from the lyrics file',
      removable: false,
    );
  }

  Future<void> _loadSavedTiming() async {
    final path = await SongLrcStore.getPath(_script.title);
    if (path != null) {
      try {
        final name = path.split('/').last.split('\\').last;
        _setTimeline(
          LrcService.matchToScript(LrcService.parseFile(path), _script),
          label: 'Timing from $name',
          removable: true,
        );
      } catch (_) {
        await SongLrcStore.removePath(_script.title);
      }
      return;
    }
    final content = await SongLrcContentStore.getContent(_script.title);
    if (content != null && mounted) _applyTimingContent(content);
  }

  void _applyTimingContent(String content) {
    _setTimeline(
      LrcService.matchToScript(LrcService.parse(content), _script),
      label: LrcService.isRehearsalTiming(content)
          ? 'Rehearsal timing'
          : 'Online synced timing',
      removable: true,
    );
  }

  void _setTimeline(
    List<(int, Duration)> timeline, {
    required String label,
    required bool removable,
  }) {
    if (timeline.isEmpty || !mounted) return;
    _scrollEngine.setTimeline(timeline);
    _timingLabel = label;
    _timingRemovable = removable;
    if (_initialized) setState(() {}); // setState isn't allowed in initState
  }

  void _removeTiming() {
    SongLrcStore.removePath(_script.title);
    SongLrcContentStore.removeContent(_script.title);
    _scrollEngine.clearTimeline();
    setState(() {
      _timingLabel = null;
      _timingRemovable = false;
    });
    _applyScriptTimestamps(); // a lyrics file's own timing still applies
  }

  // ── Recording timing in rehearsal ──────────────────────────────────────────

  void _startRecordingTiming() {
    _countdownTimer?.cancel();
    widget.syncEngine.stop();
    _scrollEngine.clearTimeline(); // taps set the positions while recording
    _scrollEngine
        .resetToStart(); // here, not in the recorder's initState (mid-build)
    setState(() {
      _countdownValue = null;
      _recordingTiming = true;
    });
  }

  void _endRecording() {
    setState(() => _recordingTiming = false);
    _keyboardFocus.requestFocus(); // the recorder held the keys
  }

  Future<void> _saveRecordedTiming(List<(int, Duration)> lineTimes) async {
    final lrc = LrcService.toLrc([
      for (final (line, time) in lineTimes) (_script.allLines[line].text, time),
    ], rehearsal: true);
    await SongLrcContentStore.saveContent(_script.title, lrc);
    await SongLrcStore.removePath(_script.title); // would take precedence
    if (!mounted) return;
    _endRecording();
    _scrollEngine.resetToStart();
    _applyTimingContent(lrc);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Timing saved. Press play and the lyrics follow it — '
          'if the band drifts, press ↓ as a line starts.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  void _cancelRecordingTiming() {
    _endRecording();
    // Back to whatever timing the song had before
    _applyScriptTimestamps();
    _loadSavedTiming();
  }

  void _seekAudio(double seconds) {
    if (!_audioService.isLoaded) return;
    _audioService.seek(Duration(microseconds: (seconds * 1e6).round()));
  }

  // ── Section jumps (with audio seek) ───────────────────────────────────────

  void _onProgressBarSeek(double fraction) {
    _scrollEngine.jumpToFraction(fraction);
    _syncAudioToScroll();
  }

  void _onRemoteCommand(RemoteAction action) {
    switch (action) {
      case RemoteAction.playPause:
        _onPlayPauseRequested();
      // Timed songs follow their timing, so speed doesn't apply
      case RemoteAction.speedUp:
        if (!_scrollEngine.isTimed) {
          widget.syncEngine.adjustSpeed(ScrollConstants.speedStep);
        }
      case RemoteAction.speedDown:
        if (!_scrollEngine.isTimed) {
          widget.syncEngine.adjustSpeed(-ScrollConstants.speedStep);
        }
      case RemoteAction.nextSection:
        _jumpNextSection();
      case RemoteAction.prevSection:
        _jumpPrevSection();
      case RemoteAction.nextSong:
        widget.onNextScript?.call();
      case RemoteAction.prevSong:
        widget.onPrevScript?.call();
      case RemoteAction.cueAdvance:
        _scrollEngine.scrollByLines(1);
        _syncAudioToScroll();
      case RemoteAction.resetToStart:
        _scrollEngine.resetToStart();
        _syncAudioToScroll();
    }
  }

  void _jumpNextSection() {
    _scrollEngine.jumpToNextSection();
    _syncAudioToScroll();
  }

  void _jumpPrevSection() {
    _scrollEngine.jumpToPrevSection();
    _syncAudioToScroll();
  }

  void _syncAudioToScroll() {
    // Timed songs seek their backing track through ScrollEngine.onSeek
    if (!_audioService.isLoaded || _scrollEngine.isTimed) return;
    _audioService.seekToFraction(_scrollEngine.progressFraction);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return TeleprompterKeyboardHandler(
      syncEngine: widget.syncEngine,
      scrollEngine: _scrollEngine,
      onToggleFullscreen: _toggleFullscreen,
      onBack: _handleEscape,
      onNextScript: widget.onNextScript,
      onPrevScript: widget.onPrevScript,
      onToggleMirror: () => setState(() => _isMirrored = !_isMirrored),
      onTapTempo: _onTapTempo,
      onPlayPauseOverride: _onPlayPauseRequested,
      onJumpNextSection: _jumpNextSection,
      onJumpPrevSection: _jumpPrevSection,
      pedalAction: _settings.pedalAction,
      focusNode: _keyboardFocus,
      child: Scaffold(
        backgroundColor: _songTheme.background,
        body: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              _scrollEngine.scrollByPixels(event.scrollDelta.dy);
            }
          },
          onPointerPanZoomUpdate: (event) {
            // Windows precision trackpads fire pan/zoom events, not scroll events.
            // panDelta.dy is positive when swiping down (scroll up), so negate.
            _scrollEngine.scrollByPixels(-event.panDelta.dy);
          },
          child: Stack(
            children: [
              MirrorTransform(enabled: _isMirrored, child: _buildCanvas()),
              // Lyrics fade out before they reach the controls bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: AppDimensions.controlsHeight + 88,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          _songTheme.background,
                          _songTheme.background.withValues(alpha: 0),
                        ],
                        stops: const [0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              _ProgressBar(
                scrollEngine: _scrollEngine,
                script: _script,
                onSeek: _onProgressBarSeek,
                accent: _songTheme.accent,
              ),
              _ClockOverlay(syncEngine: widget.syncEngine),
              if (_countdownValue != null)
                _CountdownOverlay(
                  value: _countdownValue!,
                  accent: _songTheme.accent,
                ),
              if (_notice != null) _TopNotice(text: _notice!),
              if (_audioService.isLoaded)
                _AudioPositionBar(
                  audioService: _audioService,
                  scrollEngine: _scrollEngine,
                  accent: _songTheme.accent,
                ),
              if (!_recordingTiming)
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: _audioService,
                    builder: (context, _) => ControlsOverlay(
                      syncEngine: widget.syncEngine,
                      scrollEngine: _scrollEngine,
                      onPlayPause: _onPlayPauseRequested,
                      onFullscreen: _toggleFullscreen,
                      onSettings: widget.onSettings,
                      onFormatLyrics: () =>
                          setState(() => _showFormatOverlay = true),
                      onBack: _handleBack,
                      onNextScript: widget.onNextScript,
                      onPrevScript: widget.onPrevScript,
                      onToggleMirror: () =>
                          setState(() => _isMirrored = !_isMirrored),
                      onTapTempo: _onTapTempo,
                      onSetDuration: _onSetDuration,
                      onUnloadAudio: _onUnloadAudio,
                      setlistPosition: widget.setlistPosition,
                      isFullscreen: _isFullscreen,
                      isMirrored: _isMirrored,
                      songTitle: _script.title,
                      hasAudio: _audioService.isLoaded,
                      audioFileName: _audioService.fileName,
                      audioVolume: _audioService.volume,
                      onVolumeChanged: (v) => _audioService.setVolume(v),
                      hasChords: _script.hasChordLines,
                      transposeSteps: _transposeSteps,
                      onTransposeChanged: _setTranspose,
                      cueMode: _cueMode,
                      onToggleCueMode: _toggleCueMode,
                      remoteUrl: _remoteUrl,
                      songTheme: _songTheme,
                      defaultTheme: widget.defaultTheme,
                      songHasOwnTheme: widget.songHasOwnTheme,
                      onThemeChanged: widget.onThemeChanged,
                      onThemeReset: widget.onThemeReset,
                      onMoveToDisplay: _hasSecondDisplay
                          ? _moveToSecondDisplay
                          : null,
                      isOnSecondDisplay: _isOnSecondDisplay,
                      timingLabel: _timingLabel,
                      onRecordTiming: _startRecordingTiming,
                      onRemoveTiming: _timingRemovable ? _removeTiming : null,
                    ),
                  ),
                ),
              if (_recordingTiming)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: TimingRecorder(
                    script: _script,
                    scrollEngine: _scrollEngine,
                    replacesTiming: _timingLabel != null,
                    onSave: _saveRecordedTiming,
                    onCancel: _cancelRecordingTiming,
                  ),
                ),
              if (_showFormatOverlay)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 400,
                  child: FormatOverlay(
                    script: _script,
                    formatting: _formatting,
                    onChanged: _onFormattingChanged,
                    onClose: () => setState(() => _showFormatOverlay = false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: _scrollEngine,
        builder: (context, _) {
          final screenHeight = MediaQuery.of(context).size.height;
          final anchorY = screenHeight * _settings.activeLineYOffset;
          final lineHeight = _effectiveLineHeight;
          final activeIdx = _scrollEngine.activeLineIndex;
          final pixelOffset = _scrollEngine.pixelOffset;
          final lines = _displayScript.allLines;
          // Word-by-word highlight follows the song clock of a timed song
          final songSeconds = _scrollEngine.isTimed
              ? _scrollEngine.clockSeconds
              : null;

          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: List.generate(lines.length, (i) {
                final y =
                    anchorY +
                    (i - activeIdx) * lineHeight -
                    (pixelOffset - activeIdx * lineHeight);

                if (y < -lineHeight * 2 || y > screenHeight + lineHeight * 2) {
                  return const SizedBox.shrink();
                }

                final distance = (i - activeIdx).abs();
                final proximity = distance == 0
                    ? LineProximity.active
                    : distance == 1
                    ? LineProximity.near
                    : distance <= 3
                    ? LineProximity.mid
                    : LineProximity.far;

                final isLoopBoundary =
                    _scrollEngine.loopEnabled &&
                    (i == _scrollEngine.loopStartLine ||
                        i == _scrollEngine.loopEndLine);

                // Karaoke: compute active word index for the active line
                int? activeWordIndex;
                if (i == activeIdx &&
                    songSeconds != null &&
                    lines[i].wordTimestamps != null) {
                  final ts = lines[i].wordTimestamps!;
                  activeWordIndex = ts.lastIndexWhere((t) => songSeconds >= t);
                  if (activeWordIndex < 0) activeWordIndex = 0;
                }

                return Positioned(
                  key: ValueKey(i),
                  left: 48,
                  right: 48,
                  top: y,
                  height: lineHeight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: ScriptLineWidget(
                      line: lines[i],
                      lineIndex: i,
                      proximity: proximity,
                      fontSize: _settings.fontSize,
                      isLoopBoundary: isLoopBoundary,
                      displayFont: _settings.displayFont,
                      formatting: _formatting,
                      activeWordIndex: activeWordIndex,
                      textAlignLeft: _settings.textAlignLeft,
                      showHighlight: _settings.showActiveLineHighlight,
                      theme: _songTheme,
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

// ── Progress bar (left edge) — clickable, shows section tick marks ────────────

class _ProgressBar extends StatelessWidget {
  final ScrollEngine scrollEngine;
  final Script script;
  final ValueChanged<double> onSeek;
  final Color accent;

  const _ProgressBar({
    required this.scrollEngine,
    required this.script,
    required this.onSeek,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 16,
      child: GestureDetector(
        onTapDown: (d) => _seek(d.localPosition.dy, context),
        onVerticalDragUpdate: (d) => _seek(d.localPosition.dy, context),
        behavior: HitTestBehavior.opaque,
        child: ListenableBuilder(
          listenable: scrollEngine,
          builder: (context, _) {
            final progress = scrollEngine.progressFraction;
            return Stack(
              children: [
                // Track fill
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: Column(
                    children: [
                      Flexible(
                        flex: (progress * 1000).round().clamp(1, 1000),
                        child: Container(
                          color: accent.withValues(alpha: 0.7),
                        ),
                      ),
                      Flexible(
                        flex: ((1 - progress) * 1000).round().clamp(1, 1000),
                        child: Container(
                          color: AppColors.surfaceElevated.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Section tick marks
                ...script.sections.skip(1).map((section) {
                  final frac = scrollEngine.fractionForLine(
                    section.startLineIndex,
                  );
                  return Align(
                    alignment: Alignment(0, frac * 2 - 1),
                    child: Container(
                      width: 8,
                      height: 2,
                      color: AppColors.uiHint.withValues(alpha: 0.6),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  void _seek(double localY, BuildContext context) {
    final height = context.size?.height ?? 1;
    onSeek((localY / height).clamp(0.0, 1.0));
  }
}

// ── Audio position bar (right edge) ──────────────────────────────────────────

class _AudioPositionBar extends StatelessWidget {
  final AudioService audioService;
  final ScrollEngine scrollEngine;
  final Color accent;

  const _AudioPositionBar({
    required this.audioService,
    required this.scrollEngine,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final duration = audioService.duration;
    if (duration == null || duration.inMilliseconds == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 3,
      child: StreamBuilder<Duration>(
        stream: audioService.positionStream,
        builder: (context, snap) {
          final pos = snap.data ?? Duration.zero;
          final progress = (pos.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          );
          return Column(
            children: [
              Flexible(
                flex: (progress * 1000).round(),
                child: Container(
                  color: accent.withValues(alpha: 0.5),
                ),
              ),
              Flexible(
                flex: ((1 - progress) * 1000).round().clamp(1, 1000),
                child: Container(
                  color: AppColors.surfaceElevated.withValues(alpha: 0.3),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Clock + elapsed timer ─────────────────────────────────────────────────────

class _ClockOverlay extends StatefulWidget {
  final SyncEngine syncEngine;
  const _ClockOverlay({required this.syncEngine});

  @override
  State<_ClockOverlay> createState() => _ClockOverlayState();
}

class _ClockOverlayState extends State<_ClockOverlay> {
  late Timer _ticker;
  DateTime _now = DateTime.now();

  Duration _accumulated = Duration.zero;
  DateTime? _playStartedAt;

  @override
  void initState() {
    super.initState();
    widget.syncEngine.addListener(_onEngineChanged);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  void _onEngineChanged() {
    final playing = widget.syncEngine.isPlaying;
    if (playing && _playStartedAt == null) {
      _playStartedAt = DateTime.now();
    } else if (!playing && _playStartedAt != null) {
      _accumulated += DateTime.now().difference(_playStartedAt!);
      _playStartedAt = null;
      if (widget.syncEngine.playState == PlayState.stopped) {
        _accumulated = Duration.zero;
      }
    }
  }

  Duration get _elapsed {
    var total = _accumulated;
    if (_playStartedAt != null) {
      total += DateTime.now().difference(_playStartedAt!);
    }
    return total;
  }

  @override
  void dispose() {
    _ticker.cancel();
    widget.syncEngine.removeListener(_onEngineChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _elapsed;
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final clockStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return Positioned(
      top: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            clockStr,
            style: const TextStyle(
              fontFamily: AppTextStyles.mono,
              fontSize: 13,
              color: AppColors.uiHint,
              letterSpacing: 1,
            ),
          ),
          Text(
            '$mm:$ss',
            style: const TextStyle(
              fontFamily: AppTextStyles.mono,
              fontSize: 11,
              color: AppColors.uiHint,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Duration picker dialog ────────────────────────────────────────────────────

class _DurationDialog extends StatefulWidget {
  const _DurationDialog();

  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  final _ctrl = TextEditingController(text: '3:30');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Duration? _parse(String text) {
    final parts = text.trim().split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final s = int.tryParse(parts[1]);
      if (m != null && s != null && s < 60) {
        return Duration(minutes: m, seconds: s);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Song duration'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the song length — scroll speed will be set so the lyrics finish exactly on cue.',
              style: TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 14,
                color: AppColors.uiText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(
                fontFamily: AppTextStyles.mono,
                fontSize: 22,
                color: AppColors.textPrimary,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'M:SS',
                hintStyle: const TextStyle(
                  fontFamily: AppTextStyles.mono,
                  fontSize: 22,
                  color: AppColors.uiHint,
                ),
                filled: true,
                fillColor: AppColors.surfaceSelected,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.7),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _confirm, child: const Text('Set speed')),
      ],
    );
  }

  void _confirm() {
    final duration = _parse(_ctrl.text);
    if (duration != null) {
      Navigator.of(context).pop(duration);
    }
  }
}

// ── Countdown overlay ─────────────────────────────────────────────────────────

// ── Short notice at the top ───────────────────────────────────────────────────

class _TopNotice extends StatelessWidget {
  final String text;
  const _TopNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 24,
      left: 80,
      right: 80,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  final int value;
  final Color accent;
  const _CountdownOverlay({required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: Tween<double>(
                begin: 1.4,
                end: 1.0,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: TextStyle(
                fontFamily: AppTextStyles.display,
                fontSize: 160,
                fontWeight: FontWeight.w900,
                color: accent.withValues(alpha: 0.85),
                letterSpacing: -4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
