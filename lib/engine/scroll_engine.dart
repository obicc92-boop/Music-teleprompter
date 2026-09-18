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

  // Timed playback: with a timeline (line → time into the song) the scroll
  // follows the song's clock instead of a fixed speed. Any manual move
  // (keys, pedal, progress bar) re-syncs the clock to the new position,
  // which is how a performer catches up when the band drifts.
  List<(int, double)> _timeline = const []; // (line, seconds), both ascending
  double _clock = 0.0;

  /// When set (e.g. a backing track's position), timed playback follows it
  /// instead of its own clock.
  double Function()? externalClock;

  /// Called with the new song time after a manual move in timed playback.
  void Function(double seconds)? onSeek;

  Ticker? _ticker;
  Duration _lastTickTime = Duration.zero;

  double get pixelOffset => _pixelOffset;
  int get activeLineIndex => _activeLineIndex;
  bool get loopEnabled => _loopEnabled;
  int get loopStartLine => _loopStartLine;
  int get loopEndLine => _loopEndLine;
  bool get isTimed => _timeline.isNotEmpty;

  /// The timed lines: (line, seconds), both ascending.
  List<(int, double)> get timeline => _timeline;
  double get clockSeconds => _clock;

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

  // ── Timed playback ─────────────────────────────────────────────────────────

  /// Follows [timeline] from now on, keeping the current position.
  void setTimeline(List<(int, Duration)> timeline) {
    final points = <(int, double)>[];
    for (final (line, time) in timeline) {
      final t = time.inMicroseconds / 1e6;
      if (points.isNotEmpty && (line <= points.last.$1 || t < points.last.$2)) {
        continue; // keep it moving forward in both line and time
      }
      points.add((line, t));
    }
    // Lines before the first timed one (e.g. an intro header) start at 0:00
    if (points.isNotEmpty && points.first.$1 > 0) {
      points.insert(0, (0, 0.0));
    }
    _timeline = points;
    _endFired = false;
    if (isTimed) _clock = _timeAtLine(_pixelOffset / _lineHeight);
    notifyListeners();
  }

  void clearTimeline() {
    _timeline = const [];
    notifyListeners();
  }

  // Lines after the last timed one keep the timeline's average pace
  double get _secondsPerLine {
    final first = _timeline.first;
    final last = _timeline.last;
    final lines = last.$1 - first.$1;
    return lines > 0 && last.$2 > first.$2 ? (last.$2 - first.$2) / lines : 3.0;
  }

  double _lineAtTime(double t) {
    final tl = _timeline;
    if (t <= tl.first.$2) return tl.first.$1.toDouble();
    for (var k = 0; k < tl.length - 1; k++) {
      final (la, ta) = tl[k];
      final (lb, tb) = tl[k + 1];
      if (t < tb) {
        final f = tb > ta ? (t - ta) / (tb - ta) : 1.0;
        return la + (lb - la) * f;
      }
    }
    return tl.last.$1 + (t - tl.last.$2) / _secondsPerLine;
  }

  double _timeAtLine(double line) {
    final tl = _timeline;
    if (line <= tl.first.$1) return tl.first.$2;
    for (var k = 0; k < tl.length - 1; k++) {
      final (la, ta) = tl[k];
      final (lb, tb) = tl[k + 1];
      if (line < lb) return ta + (tb - ta) * (line - la) / (lb - la);
    }
    return tl.last.$2 + (line - tl.last.$1) * _secondsPerLine;
  }

  void _tickTimed(double dt) {
    final script = _script;
    if (script == null || script.isEmpty) return;
    final external = externalClock;
    if (external != null) {
      _clock = external();
    } else if (_syncEngine.isPlaying) {
      _clock += dt;
    } else {
      return;
    }

    final lastLine = script.totalLines - 1;
    if (_loopEnabled && _lineAtTime(_clock) >= _loopEndLine) {
      _clock = _timeAtLine(_loopStartLine.toDouble());
      onSeek?.call(_clock);
    }

    final line = _lineAtTime(_clock).clamp(0.0, lastLine.toDouble());
    _pixelOffset = line * _lineHeight;
    // A line lights up when its time comes, not halfway there
    _activeLineIndex = (line + 0.001).floor().clamp(0, lastLine);

    if (!_loopEnabled && !_endFired && _clock >= _endTime) {
      _endFired = true;
      onEndReached?.call();
    }
    notifyListeners();
  }

  // The last line still needs singing: the song ends a line's length after it
  double get _endTime {
    final lastLine = (_script?.totalLines ?? 1) - 1;
    return _timeAtLine(lastLine.toDouble()) +
        (_secondsPerLine < 3.0 ? 3.0 : _secondsPerLine);
  }

  // After a manual move, the song clock jumps to match the new position
  void _syncClockToPosition() {
    if (!isTimed) return;
    _clock = _timeAtLine(_pixelOffset / _lineHeight);
    if (_clock < _endTime) _endFired = false; // moved back: it can end again
    onSeek?.call(_clock);
  }

  // ── Ticking ────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (!_isRunning) return;

    final dt = _lastTickTime == Duration.zero
        ? 0.0
        : (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    if (isTimed) {
      _tickTimed(dt);
      return;
    }

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
    _syncClockToPosition();
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
    _syncClockToPosition();
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
    _syncClockToPosition();
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
    _syncClockToPosition();
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
