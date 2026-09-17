import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../engine/sync_engine.dart';
import '../engine/scroll_engine.dart';
import '../models/script.dart';
import '../models/script_formatting.dart';
import '../services/audio_service.dart';
import '../services/chord_transposer.dart';
import '../services/remote_control_server.dart';
import '../services/song_theme_store.dart';
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
import '../services/settings_service.dart';
import '../services/formatting_service.dart';

class TeleprompterView extends StatefulWidget {
  final Script script;
  final SyncEngine syncEngine;
  final AppSettings settings;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback? onNextScript;
  final VoidCallback? onPrevScript;
  final String? setlistPosition;

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
  List<(int, Duration)> _lrcTimestamps = [];
  String? _lrcFileName;
  int _transposeSteps = 0;
  int? _countdownValue;
  SongTheme _songTheme = SongTheme.defaultTheme;
  bool _isOnSecondDisplay = false;
  final List<DateTime> _tapTimes = [];

  final _formattingService = FormattingService();

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _script = widget.script;

    _scrollEngine = ScrollEngine(syncEngine: widget.syncEngine);
    _scrollEngine.attach(this);
    _scrollEngine.setScript(_script, _effectiveLineHeight);
    _syncEndReachedCallback();
    _scrollEngine.start();

    _audioService = AudioService();
    widget.syncEngine.addListener(_onSyncEngineChanged);

    _remoteServer = RemoteControlServer(onCommand: _onRemoteCommand);
    _remoteServer.start().then((url) {
      if (mounted) setState(() => _remoteUrl = url);
    });

    _loadFormatting();
    _loadSavedAudio();
    _loadSavedTranspose();
    _loadSavedTheme();
    _loadSavedLrc();
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

  Future<void> _loadSavedTheme() async {
    final theme = await SongThemeStore.getTheme(_script.title);
    if (mounted) setState(() => _songTheme = theme);
  }

  void _setTheme(SongTheme theme) {
    setState(() => _songTheme = theme);
    SongThemeStore.saveTheme(_script.title, theme);
  }

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
      if (!mounted) { t.cancel(); return; }
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
    _countdownTimer?.cancel();
    _remoteServer.stop();
    widget.syncEngine.removeListener(_onSyncEngineChanged);
    _audioService.dispose();
    _scrollEngine.dispose();
    super.dispose();
  }



  Script get _displayScript =>
      ChordTransposer.transposeScript(_script, _transposeSteps);

  double get _effectiveLineHeight =>
      _script.hasChordLines ? _settings.fontSize * 3.0 : _settings.fontSize * 2.0;

  @override
  void didUpdateWidget(TeleprompterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings != oldWidget.settings) {
      setState(() => _settings = widget.settings);
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
            ? () => Future.delayed(
                  const Duration(seconds: 3),
                  () { if (mounted) widget.onNextScript!(); },
                )
            : null;
  }

  // ── Fullscreen / back ──────────────────────────────────────────────────────

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    setState(() => _isFullscreen = next);
    await windowManager.setFullScreen(next);
  }

  bool get _hasSecondDisplay =>
      PlatformDispatcher.instance.displays.length > 1;

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
    _onUnloadLrc(); // LRC requires audio — remove it too
    _audioService.unload();
    await SongAudioStore.removePath(_script.title);
    setState(() {});
  }

  // ── LRC sync ───────────────────────────────────────────────────────────────

  Future<void> _loadSavedLrc() async {
    // Check file path first, then fall back to stored content (online search results)
    final path = await SongLrcStore.getPath(_script.title);
    if (path != null) {
      if (mounted) await _applyLrcFromFile(path);
      return;
    }
    final content = await SongLrcContentStore.getContent(_script.title);
    if (content != null && mounted) {
      final lines = LrcService.parse(content);
      _applyLrcLines(lines, displayName: 'Online lyrics');
    }
  }

  Future<void> _applyLrcFromFile(String path) async {
    try {
      final lines = LrcService.parseFile(path);
      final name = path.split('/').last.split('\\').last;
      _applyLrcLines(lines, displayName: name);
    } catch (_) {
      await SongLrcStore.removePath(_script.title);
    }
  }

  void _applyLrcLines(List<LrcLine> lines, {required String displayName}) {
    final timestamps = LrcService.matchToScript(lines, _script);
    setState(() {
      _lrcTimestamps = timestamps;
      _lrcFileName = displayName;
    });
    _startLrcSync();
  }

  void _startLrcSync() {
    _scrollEngine.stop();
    // positionStream in _buildCanvas drives scroll when LRC is active
  }

  void _stopLrcSync() {
    if (_lrcTimestamps.isEmpty) return;
    _scrollEngine.start();
  }

  void _onUnloadLrc() {
    if (_lrcTimestamps.isEmpty) return;
    _stopLrcSync();
    SongLrcStore.removePath(_script.title);
    SongLrcContentStore.removeContent(_script.title);
    setState(() {
      _lrcTimestamps = [];
      _lrcFileName = null;
    });
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
      case RemoteAction.speedUp:
        widget.syncEngine.adjustSpeed(0.1);
      case RemoteAction.speedDown:
        widget.syncEngine.adjustSpeed(-0.1);
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
    if (!_audioService.isLoaded) return;
    _audioService.seekToFraction(_scrollEngine.progressFraction);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return TeleprompterKeyboardHandler(
      syncEngine: widget.syncEngine,
      scrollEngine: _scrollEngine,
      onToggleFullscreen: _toggleFullscreen,
      onBack: _handleBack,
      onNextScript: widget.onNextScript,
      onPrevScript: widget.onPrevScript,
      onToggleMirror: () => setState(() => _isMirrored = !_isMirrored),
      onTapTempo: _onTapTempo,
      onPlayPauseOverride: _onPlayPauseRequested,
      onJumpNextSection: _jumpNextSection,
      onJumpPrevSection: _jumpPrevSection,
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
            MirrorTransform(
              enabled: _isMirrored,
              child: StreamBuilder<Duration>(
                stream: _audioService.positionStream,
                builder: (context, snap) {
                  final pos = snap.data;
                  if (pos != null && _lrcTimestamps.isNotEmpty) {
                    final idx = LrcService.activeLineIndex(_lrcTimestamps, pos);
                    if (idx != null) _scrollEngine.jumpToLine(idx);
                  }
                  return _buildCanvas(pos != null
                      ? pos.inMicroseconds / 1000000.0
                      : null);
                },
              ),
            ),
            _ProgressBar(scrollEngine: _scrollEngine, script: _script, onSeek: _onProgressBarSeek),
            _ClockOverlay(syncEngine: widget.syncEngine),
            if (_countdownValue != null)
              _CountdownOverlay(value: _countdownValue!),
            if (_audioService.isLoaded)
              _AudioPositionBar(
                audioService: _audioService,
                scrollEngine: _scrollEngine,
              ),
            Positioned.fill(
              child: ListenableBuilder(
              listenable: _audioService,
              builder: (context, _) => ControlsOverlay(
                syncEngine: widget.syncEngine,
                scrollEngine: _scrollEngine,
                onFullscreen: _toggleFullscreen,
                onSettings: widget.onSettings,
                onFormatLyrics: () => setState(() => _showFormatOverlay = true),
                onBack: _handleBack,
                onNextScript: widget.onNextScript,
                onPrevScript: widget.onPrevScript,
                onToggleMirror: () => setState(() => _isMirrored = !_isMirrored),
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
                onThemeChanged: _setTheme,
                onMoveToDisplay: _hasSecondDisplay ? _moveToSecondDisplay : null,
                isOnSecondDisplay: _isOnSecondDisplay,
                onUnloadLrc: _lrcTimestamps.isNotEmpty ? _onUnloadLrc : null,
                hasLrc: _lrcTimestamps.isNotEmpty,
                lrcFileName: _lrcFileName,
              ),
            )),
            if (_showFormatOverlay)
              Positioned(
                right: 0, top: 0, bottom: 0, width: 400,
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

  Widget _buildCanvas([double? audioPositionSeconds]) {
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

            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: List.generate(lines.length, (i) {
                  final y = anchorY + (i - activeIdx) * lineHeight -
                      (pixelOffset - activeIdx * lineHeight);

                  if (y < -lineHeight * 2 ||
                      y > screenHeight + lineHeight * 2) {
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

                  final isLoopBoundary = _scrollEngine.loopEnabled &&
                      (i == _scrollEngine.loopStartLine ||
                          i == _scrollEngine.loopEndLine);

                  // Karaoke: compute active word index for the active line
                  int? activeWordIndex;
                  if (i == activeIdx &&
                      audioPositionSeconds != null &&
                      lines[i].wordTimestamps != null) {
                    final ts = lines[i].wordTimestamps!;
                    activeWordIndex = ts.lastIndexWhere(
                        (t) => audioPositionSeconds >= t);
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

  const _ProgressBar({
    required this.scrollEngine,
    required this.script,
    required this.onSeek,
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
                        child: Container(color: AppColors.accent.withValues(alpha: 0.7)),
                      ),
                      Flexible(
                        flex: ((1 - progress) * 1000).round().clamp(1, 1000),
                        child: Container(color: AppColors.surfaceElevated.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                ),
                // Section tick marks
                ...script.sections.skip(1).map((section) {
                  final frac = scrollEngine.fractionForLine(section.startLineIndex);
                  return Align(
                    alignment: Alignment(0, frac * 2 - 1),
                    child: Container(
                      width: 8,
                      height: 2,
                      color: AppColors.sectionHeader.withValues(alpha: 0.6),
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

  const _AudioPositionBar({
    required this.audioService,
    required this.scrollEngine,
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
          final progress =
              (pos.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
          return Column(
            children: [
              Flexible(
                flex: (progress * 1000).round(),
                child: Container(
                    color: AppColors.accent.withValues(alpha: 0.5)),
              ),
              Flexible(
                flex: ((1 - progress) * 1000).round().clamp(1, 1000),
                child: Container(
                    color: AppColors.surfaceElevated.withValues(alpha: 0.3)),
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
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 13,
              color: AppColors.sectionHeader,
              letterSpacing: 1,
            ),
          ),
          Text(
            '$mm:$ss',
            style: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 11,
              color: AppColors.dimmedLine,
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
      backgroundColor: AppColors.surface,
      title: const Text(
        'Song Duration',
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 14,
          color: AppColors.activeLine,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the song length — scroll speed will be set so the lyrics finish exactly on cue.',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 12,
              color: AppColors.sectionHeader,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 22,
              color: AppColors.activeLine,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'M:SS',
              hintStyle: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 22,
                color: AppColors.dimmedLine,
              ),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              color: AppColors.sectionHeader,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text(
            'Set Speed',
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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

class _CountdownOverlay extends StatelessWidget {
  final int value;
  const _CountdownOverlay({required this.value});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: Tween<double>(begin: 1.4, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOut),
              ),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 160,
                fontWeight: FontWeight.w900,
                color: AppColors.accent.withValues(alpha: 0.85),
                letterSpacing: -4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
