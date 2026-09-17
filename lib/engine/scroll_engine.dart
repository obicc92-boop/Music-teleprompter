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

  // End-of-song callback — fired once when the scroll reaches the last line
  VoidCallback? onEndReached;
  bool _endFired = false;

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
    _endFired = false;
    notifyListeners();
  }

  /// Changes the line height (e.g. a new font size) without losing the
  /// reading position.
  void setLineHeight(double height) {
    if (height == _lineHeight) return;
    _pixelOffset = _pixelOffset / _lineHeight * height;
    _lineHeight = height;
    notifyListeners();
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

    if (!_loopEnabled && !_endFired && _pixelOffset >= maxOffset && maxOffset > 0) {
      _endFired = true;
      onEndReached?.call();
    }

    if (_loopEnabled) {
      final loopEndOffset = _loopEndLine * _lineHeight;
      if (_pixelOffset >= loopEndOffset) {
        _pixelOffset = _loopStartLine * _lineHeight;
        _activeLineIndex = _loopStartLine;
        _endFired = false; // allow end-of-song to fire again if loop is later disabled
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

  void scrollByPixels(double delta) {
    final script = _script;
    if (script == null) return;
    if (delta < 0) _endFired = false; // allow re-trigger if user scrolls back
    final maxOffset = (script.totalLines - 1) * _lineHeight;
    _pixelOffset = (_pixelOffset + delta).clamp(0.0, maxOffset);
    _activeLineIndex =
        (_pixelOffset / _lineHeight).round().clamp(0, script.totalLines - 1);
    notifyListeners();
  }

  void setLoopRange(int startLine, int endLine) {
    _loopStartLine = startLine;
    _loopEndLine = endLine;
  }

  void setLoopEnabled(bool enabled) {
    _loopEnabled = enabled;
    if (enabled) _snapLoopToCurrentSection();
    notifyListeners();
  }

  void _snapLoopToCurrentSection() {
    final script = _script;
    if (script == null || script.sections.isEmpty) {
      _loopStartLine = 0;
      _loopEndLine = (script?.totalLines ?? 1) - 1;
      return;
    }
    final sectionIdx = script.sectionIndexForLine(_activeLineIndex);
    _loopStartLine = script.sections[sectionIdx].startLineIndex;
    _loopEndLine = (sectionIdx + 1 < script.sections.length)
        ? script.sections[sectionIdx + 1].startLineIndex
        : script.totalLines - 1;
  }

  void jumpToFraction(double fraction) {
    final script = _script;
    if (script == null || script.isEmpty) return;
    final maxOffset = (script.totalLines - 1) * _lineHeight;
    _pixelOffset = (fraction.clamp(0.0, 1.0) * maxOffset);
    _activeLineIndex = (_pixelOffset / _lineHeight).round().clamp(0, script.totalLines - 1);
    _endFired = false;
    notifyListeners();
  }

  /// Returns the fraction (0–1) at which [lineIndex] sits.
  double fractionForLine(int lineIndex) {
    final script = _script;
    if (script == null || script.isEmpty) return 0.0;
    final maxOffset = (script.totalLines - 1) * _lineHeight;
    if (maxOffset <= 0) return 0.0;
    return (lineIndex * _lineHeight / maxOffset).clamp(0.0, 1.0);
  }

  void resetToStart() {
    _pixelOffset = 0.0;
    _activeLineIndex = 0;
    _endFired = false;
    notifyListeners();
  }

  /// 0.0 – 1.0 fraction of how far the scroll has progressed through the script.
  double get progressFraction {
    final script = _script;
    if (script == null || script.isEmpty) return 0.0;
    final maxOffset = (script.totalLines - 1) * _lineHeight;
    if (maxOffset <= 0) return 0.0;
    return (_pixelOffset / maxOffset).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}
