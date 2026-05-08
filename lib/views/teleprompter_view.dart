import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../engine/sync_engine.dart';
import '../engine/scroll_engine.dart';
import '../models/script.dart';
import '../models/script_formatting.dart';
import '../utils/constants.dart';
import '../utils/keyboard_handler.dart';
import '../widgets/controls_overlay.dart';
import '../widgets/format_overlay.dart';
import '../widgets/lyrics_edit_overlay.dart';
import '../widgets/script_line_widget.dart';
import '../services/settings_service.dart';
import '../services/formatting_service.dart';
import '../services/word_recognition_service.dart';
import '../services/speech_to_text_recognition.dart';
import '../services/whisper_recognition.dart';

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
  late AppSettings _settings;
  late Script _script;
  ScriptFormatting _formatting = ScriptFormatting.empty;
  bool _isFullscreen = false;
  bool _showFormatOverlay = false;
  bool _showEditOverlay = false;

  // Voice word sync
  List<({int lineIndex, int wordIndex, String word})> _wordList = [];
  int _globalWordIndex = 0;
  StreamSubscription<void>? _onsetSub;
  StreamSubscription<String>? _wordSub;
  WordRecognitionService? _recognitionService;

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
    _loadFormatting();
    _wordList = _buildWordList(_script);
    _setupWordSync();
  }

  Future<void> _loadFormatting() async {
    final fmt = await _formattingService.load(_script.title);
    if (mounted) setState(() => _formatting = fmt);
  }

  double get _effectiveLineHeight => _settings.fontSize * 2.0;

  @override
  void didUpdateWidget(TeleprompterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings != oldWidget.settings) {
      final oldMode = _settings.wordSyncMode;
      setState(() => _settings = widget.settings);
      _syncEndReachedCallback();
      if (widget.settings.wordSyncMode != oldMode) {
        _globalWordIndex = 0;
        _setupWordSync();
      }
    }
  }

  void _onFormattingChanged(ScriptFormatting fmt) {
    setState(() => _formatting = fmt);
    _formattingService.save(_script.title, fmt);
  }

  void _onLyricsEdited(Script updated) {
    setState(() {
      _script = updated;
      _showEditOverlay = false;
      _wordList = _buildWordList(updated);
      _globalWordIndex = 0;
    });
    _scrollEngine.setScript(_script, _effectiveLineHeight);
    _setupWordSync();
  }

  List<({int lineIndex, int wordIndex, String word})> _buildWordList(Script script) {
    final list = <({int lineIndex, int wordIndex, String word})>[];
    for (int i = 0; i < script.allLines.length; i++) {
      final line = script.allLines[i];
      if (line.isSectionHeader || line.isEmpty || line.words.isEmpty) continue;
      for (int w = 0; w < line.words.length; w++) {
        list.add((lineIndex: i, wordIndex: w, word: line.words[w]));
      }
    }
    return list;
  }

  void _setupWordSync() {
    _onsetSub?.cancel();
    _wordSub?.cancel();
    _recognitionService?.dispose();
    _recognitionService = null;

    final mode = _settings.wordSyncMode;
    if (mode == WordSyncMode.off) return;

    if (mode == WordSyncMode.onset) {
      _onsetSub = widget.syncEngine.onsetStream.listen((_) => _onOnset());
      return;
    }

    // ASR-based modes
    _recognitionService = switch (mode) {
      WordSyncMode.systemStt => SpeechToTextRecognition(),
      WordSyncMode.whisper => WhisperRecognition(
          rawAudioStream: widget.syncEngine.rawAudioStream,
          modelPath: _settings.whisperModelPath,
        ),
      WordSyncMode.whisperAlign => WhisperRecognition(
          rawAudioStream: widget.syncEngine.rawAudioStream,
          modelPath: _settings.whisperModelPath,
          wordTimestamps: true,
        ),
      _ => null,
    };

    if (_recognitionService != null) {
      _wordSub = _recognitionService!.wordStream.listen(_onWordRecognized);
      _recognitionService!.start(lyrics: _script.rawText);
    }
  }

  void _onOnset() {
    if (!mounted) return;
    if (_wordList.isEmpty || _globalWordIndex >= _wordList.length - 1) return;
    setState(() => _globalWordIndex++);
    _scrollEngine.jumpToLine(_wordList[_globalWordIndex].lineIndex);
  }

  void _onWordRecognized(String word) {
    if (!mounted || _wordList.isEmpty) return;
    // Search forward in a window of 15 words from the current position
    final start = _globalWordIndex;
    final end = min(_wordList.length, start + 15);
    for (int i = start; i < end; i++) {
      final script = _wordList[i].word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (_wordsMatch(script, word)) {
        setState(() => _globalWordIndex = i);
        _scrollEngine.jumpToLine(_wordList[i].lineIndex);
        break;
      }
    }
  }

  bool _wordsMatch(String a, String b) {
    if (a == b) return true;
    if (a.length < 3 || b.length < 3) return false;
    // Match if first 3 chars agree (handles plural/tense variation)
    return a.substring(0, 3) == b.substring(0, 3);
  }

  int _highlightedWordForLine(int lineIndex) {
    if (_settings.wordSyncMode == WordSyncMode.off || _wordList.isEmpty) return -1;
    final entry = _wordList[_globalWordIndex.clamp(0, _wordList.length - 1)];
    return entry.lineIndex == lineIndex ? entry.wordIndex : -1;
  }

  void _syncEndReachedCallback() {
    _scrollEngine.onEndReached = (_settings.autoAdvance && widget.onNextScript != null)
        ? () {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) widget.onNextScript!();
            });
          }
        : null;
  }

  @override
  void dispose() {
    _onsetSub?.cancel();
    _wordSub?.cancel();
    _recognitionService?.dispose();
    _scrollEngine.dispose();
    super.dispose();
  }

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    setState(() => _isFullscreen = next);
    await windowManager.setFullScreen(next);
  }

  void _handleBack() {
    if (_isFullscreen) windowManager.setFullScreen(false);
    widget.syncEngine.stop();
    widget.onBack();
  }

  void _openSettings() {
    widget.onSettings();
  }

  @override
  Widget build(BuildContext context) {
    return TeleprompterKeyboardHandler(
      syncEngine: widget.syncEngine,
      scrollEngine: _scrollEngine,
      onToggleFullscreen: _toggleFullscreen,
      onBack: _handleBack,
      onNextScript: widget.onNextScript,
      onPrevScript: widget.onPrevScript,
      pedalAction: _settings.pedalAction,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            _buildCanvas(),
            ControlsOverlay(
              syncEngine: widget.syncEngine,
              scrollEngine: _scrollEngine,
              onFullscreen: _toggleFullscreen,
              onSettings: _openSettings,
              onEditLyrics: () => setState(() => _showEditOverlay = true),
              onFormatLyrics: () => setState(() => _showFormatOverlay = true),
              onBack: _handleBack,
              onNextScript: widget.onNextScript,
              onPrevScript: widget.onPrevScript,
              setlistPosition: widget.setlistPosition,
              isFullscreen: _isFullscreen,
              songTitle: _script.title,
            ),
            if (_showFormatOverlay)
              Positioned.fill(
                child: FormatOverlay(
                  script: _script,
                  formatting: _formatting,
                  onChanged: _onFormattingChanged,
                  onClose: () => setState(() => _showFormatOverlay = false),
                ),
              ),
            if (_showEditOverlay)
              Positioned.fill(
                child: LyricsEditOverlay(
                  script: _script,
                  onSaved: _onLyricsEdited,
                  onClose: () => setState(() => _showEditOverlay = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _scrollEngine.scrollByPixels(event.scrollDelta.dy);
        }
      },
      child: RepaintBoundary(
      child: ListenableBuilder(
        listenable: _scrollEngine,
        builder: (context, _) {
          final screenHeight = MediaQuery.of(context).size.height;
          final anchorY = screenHeight * AppDimensions.activeLineYOffset;
          final lineHeight = _effectiveLineHeight;
          final activeIdx = _scrollEngine.activeLineIndex;
          final pixelOffset = _scrollEngine.pixelOffset;
          final lines = _script.allLines;

          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: List.generate(lines.length, (i) {
                final y = anchorY + (i - activeIdx) * lineHeight -
                    (pixelOffset - activeIdx * lineHeight);

                if (y < -lineHeight * 2 || y > screenHeight + lineHeight * 2) {
                  return const SizedBox.shrink();
                }

                final distance = (i - activeIdx).abs();
                LineProximity proximity;
                if (distance == 0) {
                  proximity = LineProximity.active;
                } else if (distance == 1) {
                  proximity = LineProximity.near;
                } else if (distance <= 3) {
                  proximity = LineProximity.mid;
                } else {
                  proximity = LineProximity.far;
                }

                final isLoopBoundary = _scrollEngine.loopEnabled &&
                    (i == _scrollEngine.loopStartLine ||
                        i == _scrollEngine.loopEndLine);

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
                      karaokeEnabled: _settings.karaokeMode,
                      highlightedWordIndex: _highlightedWordForLine(i),
                      isLoopBoundary: isLoopBoundary,
                      displayFont: _settings.displayFont,
                      formatting: _formatting,
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
      ),
    );
  }
}
