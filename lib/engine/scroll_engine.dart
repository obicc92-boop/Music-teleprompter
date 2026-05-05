import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import '../models/script.dart';
import 'sync_engine.dart';

class ScrollEngine extends ChangeNotifier {
  final SyncEngine _syncEngine;

  Script? _script;
  double _pixelOffset = 0.0;
  double _lineHeight = 80.0;
  int _activeLineIndex = 0;
  bool _isRunning = false;

  // Loop state
  bool _loopEnabled = false;
  int _loopStartLine = 0;
  int _loopEndLine = 0;

  Ticker? _ticker;
  Duration _lastTickTime = Duration.zero;

  double get pixelOffset => _pixelOffset;
  int get activeLineIndex => _activeLineIndex;
  bool get loopEnabled => _loopEnabled;
  int get loopStartLine => _loopStartLine;
  int get loopEndLine => _loopEndLine;

  ScrollEngine({required SyncEngine syncEngine}) : _syncEngine = syncEngine;

  void attach(TickerProvider vsync) {
    _ticker?.dispose();
    _ticker = vsync.createTicker(_onTick);
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _lastTickTime = Duration.zero;
    _ticker?.start();
  }

  void stop() {
    _isRunning = false;
    _ticker?.stop();
  }

  void setScript(Script script, double lineHeight) {
    _script = script;
    _lineHeight = lineHeight;
    _pixelOffset = 0.0;
    _activeLineIndex = 0;
    notifyListeners();
  }

  void setLineHeight(double height) {
    _lineHeight = height;
  }

  void _onTick(Duration elapsed) {
    if (!_isRunning) return;

    final dt = _lastTickTime == Duration.zero
        ? 0.0
        : (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    final deltaPixels = _syncEngine.tickScrollSpeed(dt);
    if (deltaPixels.abs() < 0.001) return;

    _advance(deltaPixels);
  }

  void _advance(double deltaPixels) {
    final script = _script;
    if (script == null || script.isEmpty) return;

    final maxOffset = (script.totalLines - 1) * _lineHeight;

    _pixelOffset = (_pixelOffset + deltaPixels).clamp(0.0, maxOffset);
    _activeLineIndex = (_pixelOffset / _lineHeight).round().clamp(0, script.totalLines - 1);

    if (_loopEnabled) {
      final loopEndOffset = _loopEndLine * _lineHeight;
      if (_pixelOffset >= loopEndOffset) {
        _pixelOffset = _loopStartLine * _lineHeight;
        _activeLineIndex = _loopStartLine;
      }
    }

    notifyListeners();
  }

  void jumpToLine(int lineIndex) {
    final script = _script;
    if (script == null) return;
    _activeLineIndex = lineIndex.clamp(0, script.totalLines - 1);
    _pixelOffset = _activeLineIndex * _lineHeight;
    notifyListeners();
  }

  void jumpToNextSection() {
    final script = _script;
    if (script == null) return;
    jumpToLine(script.nextSectionStartLine(_activeLineIndex));
  }

  void jumpToPrevSection() {
    final script = _script;
    if (script == null) return;
    jumpToLine(script.prevSectionStartLine(_activeLineIndex));
  }

  void scrollByLines(int delta) {
    jumpToLine(_activeLineIndex + delta);
  }

  void setLoopRange(int startLine, int endLine) {
    _loopStartLine = startLine;
    _loopEndLine = endLine;
  }

  void setLoopEnabled(bool enabled) {
    _loopEnabled = enabled;
    notifyListeners();
  }

  void resetToStart() {
    _pixelOffset = 0.0;
    _activeLineIndex = 0;
    notifyListeners();
  }

  // Returns how far (0.0–1.0) the active line is into the current word
  double wordProgress(double bpm) {
    if (bpm <= 0) return 0.0;
    final beatDuration = 60.0 / bpm;
    return (DateTime.now().millisecondsSinceEpoch / 1000.0 % beatDuration) / beatDuration;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}
