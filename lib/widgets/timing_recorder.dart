import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/scroll_engine.dart';
import '../models/script.dart';
import '../utils/app_platform.dart';
import '../utils/constants.dart';

/// Rehearsal mode for timing a song: press Space, the foot pedal, or tap the
/// screen on a phone as the song starts and then as each line starts. The taps
/// become the song's timing, so at the show the lyrics follow the way it was
/// rehearsed.
class TimingRecorder extends StatefulWidget {
  final Script script;
  final ScrollEngine scrollEngine;

  /// The song already has timing that saving will replace.
  final bool replacesTiming;
  final void Function(List<(int, Duration)> lineTimes) onSave;
  final VoidCallback onCancel;

  const TimingRecorder({
    super.key,
    required this.script,
    required this.scrollEngine,
    required this.replacesTiming,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<TimingRecorder> createState() => TimingRecorderState();
}

class TimingRecorderState extends State<TimingRecorder> {
  final _focusNode = FocusNode(debugLabel: 'TimingRecorder');
  final _stopwatch = Stopwatch();
  Timer? _clockTimer;
  late final List<int> _lyricLines; // the lines that get a tap
  final List<Duration> _taps = []; // one per lyric line timed so far

  bool get _started => _stopwatch.isRunning;
  bool get _done => _taps.length == _lyricLines.length;
  bool get _canSave => _taps.length >= 2; // two lines give the pace for the rest

  @override
  void initState() {
    super.initState();
    _lyricLines = [
      for (var i = 0; i < widget.script.allLines.length; i++)
        if (!widget.script.allLines[i].isSectionHeader &&
            !widget.script.allLines[i].isEmpty)
          i,
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _start() {
    _stopwatch.start();
    _clockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  /// One line timed. On a phone the whole screen is the tap target.
  void tap() => _tap();

  void _tap() {
    if (!_started) return _start();
    if (_done) return;
    _taps.add(_stopwatch.elapsed);
    widget.scrollEngine.jumpToLine(_lyricLines[_taps.length - 1]);
    setState(() {});
  }

  // Takes back the last tap; the clock keeps running, so tapping again when
  // that line really starts records the right time
  void _undo() {
    if (_taps.isEmpty) return;
    _taps.removeLast();
    if (_taps.isEmpty) {
      widget.scrollEngine.resetToStart();
    } else {
      widget.scrollEngine.jumpToLine(_lyricLines[_taps.length - 1]);
    }
    setState(() {});
  }

  void _save() {
    if (!_canSave) return;
    widget.onSave([
      for (var i = 0; i < _taps.length; i++) (_lyricLines[i], _taps[i]),
    ]);
  }

  Future<void> _cancel() async {
    if (_taps.length >= 3) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard this recording?', style: _titleStyle),
          content: Text(
            '${_taps.length} lines are timed so far. The song keeps the timing it had before.',
            style: _bodyStyle,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep recording', style: _buttonStyle),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Discard',
                  style: _buttonStyle.copyWith(
                      color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (discard != true) {
        _focusNode.requestFocus();
        return;
      }
    }
    widget.onCancel();
  }

  // Space, ↓ and the pedal's forward keys tap; ↑ and its back key undo
  static final _forwardKeys = {
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  };
  static final _backKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.backspace,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final key = event.logicalKey;

    if (_forwardKeys.contains(key)) {
      // Once every line is timed, the pedal saves — no hands needed
      _done ? _save() : _tap();
    } else if (_backKeys.contains(key)) {
      _undo();
    } else if (key == LogicalKeyboardKey.escape) {
      _cancel();
    } else if (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.keyM) {
      return KeyEventResult.ignored; // fullscreen and mirror still work
    }
    // Everything else (next song, reset…) would lose the recording
    return KeyEventResult.handled;
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  static const _titleStyle = TextStyle(
    fontFamily: AppTextStyles.ui,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const _bodyStyle = TextStyle(
    fontFamily: AppTextStyles.ui,
    fontSize: 12,
    color: AppColors.uiText,
    height: 1.5,
  );

  static const _buttonStyle = TextStyle(
    fontFamily: AppTextStyles.ui,
    fontSize: 12,
    color: AppColors.uiHint,
  );

  String get _clock {
    final s = _stopwatch.elapsed.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  String get _headline {
    if (!_started) return 'Record timing';
    if (_done) return 'All ${_lyricLines.length} lines timed';
    return 'Line ${_taps.length + 1} of ${_lyricLines.length}';
  }

  String get _instruction {
    final press = AppPlatform.isTouch ? 'tap the screen' : 'press Space or the pedal';
    if (!_started) {
      return 'Start the song, then $press right when it begins. '
          '${widget.replacesTiming ? "Saving replaces this song's current timing." : ''}';
    }
    if (_done) {
      return AppPlatform.isTouch
          ? 'Every line is timed — save it below · Undo redoes the last line'
          : 'Press Enter or the pedal to save · ↑ redoes the last line';
    }
    final next = widget.script.allLines[_lyricLines[_taps.length]].text.trim();
    return '${AppPlatform.isTouch ? "Tap the screen" : "Tap"} as this line starts: “$next”';
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: Material(
        color: AppColors.sidebar.withValues(alpha: 0.97),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.hairline)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
          child: MediaQuery.sizeOf(context).width < 640
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _RecBadge(
                          recording: _started && !_done,
                          clock: _started ? _clock : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _headlineAndInstruction()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: _buttons(),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _RecBadge(
                      recording: _started && !_done,
                      clock: _started ? _clock : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _headlineAndInstruction()),
                    const SizedBox(width: 12),
                    ..._buttons(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _headlineAndInstruction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_headline, style: _titleStyle),
        const SizedBox(height: 2),
        Text(
          _instruction,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _bodyStyle,
        ),
      ],
    );
  }

  List<Widget> _buttons() => [
        if (_started)
          _button('Undo', Icons.undo_rounded, _taps.isEmpty ? null : _undo,
              tooltip: 'Redo the last line (↑)'),
        _button('Cancel', Icons.close_rounded, _cancel, tooltip: 'Esc'),
        const SizedBox(width: 4),
        _started
            ? _primaryButton('Save', _canSave ? _save : null,
                tooltip: _done
                    ? 'Save this timing (Enter)'
                    : 'Save now — untimed lines keep the same pace')
            : _primaryButton('Start', _start,
                tooltip: 'Press when the song starts (Space)'),
      ];

  // Clicking a button would take focus away from the keys, so give it back
  VoidCallback? _refocusAfter(VoidCallback? action) => action == null
      ? null
      : () {
          action();
          _focusNode.requestFocus();
        };

  Widget _button(String label, IconData icon, VoidCallback? onPressed,
      {required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: _refocusAfter(onPressed),
        icon: Icon(icon,
            size: 16,
            color: onPressed == null ? AppColors.uiHint : AppColors.uiHint),
        label: Text(label,
            style: _buttonStyle.copyWith(
                color: onPressed == null ? AppColors.uiHint : AppColors.uiHint)),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed,
      {required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: ElevatedButton(
        onPressed: _refocusAfter(onPressed),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.surfaceElevated,
          disabledForegroundColor: AppColors.uiHint,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTextStyles.ui,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RecBadge extends StatelessWidget {
  final bool recording;
  final String? clock;
  const _RecBadge({required this.recording, required this.clock});

  @override
  Widget build(BuildContext context) {
    final color = recording ? const Color(0xFFFF4D4D) : AppColors.uiHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 6),
          Text(
            clock == null ? 'REC' : 'REC $clock',
            style: TextStyle(
              fontFamily: AppTextStyles.mono,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
