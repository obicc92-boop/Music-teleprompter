import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/sync_engine.dart';
import '../engine/scroll_engine.dart';
import '../models/shortcuts.dart';
import '../utils/constants.dart';

class TeleprompterKeyboardHandler extends StatefulWidget {
  final Widget child;
  final SyncEngine syncEngine;
  final ScrollEngine scrollEngine;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onBack;
  final VoidCallback? onNextScript;
  final VoidCallback? onPrevScript;
  final VoidCallback? onToggleMirror;
  final VoidCallback? onTapTempo;
  final VoidCallback? onEdit;
  final VoidCallback? onPlayPauseOverride;
  final String pedalAction;

  /// Which key does what; the user's own choices, or the defaults.
  final ShortcutMap shortcuts;

  /// Lets the owner give keys back after something else (e.g. the timing
  /// recorder) held focus.
  final FocusNode? focusNode;

  /// False while something on screen types (a line being edited), so
  /// letters and Space reach it instead of driving the song.
  final bool enabled;

  // Optional overrides for section jumps — called instead of scrollEngine directly.
  // Use these when you need side effects (e.g. seeking audio) on section change.
  final VoidCallback? onJumpNextSection;
  final VoidCallback? onJumpPrevSection;

  const TeleprompterKeyboardHandler({
    super.key,
    required this.child,
    required this.syncEngine,
    required this.scrollEngine,
    required this.onToggleFullscreen,
    required this.onBack,
    this.onNextScript,
    this.onPrevScript,
    this.onToggleMirror,
    this.onTapTempo,
    this.onEdit,
    this.onPlayPauseOverride,
    this.pedalAction = 'nextSection',
    this.shortcuts = ShortcutMap.standard,
    this.focusNode,
    this.enabled = true,
    this.onJumpNextSection,
    this.onJumpPrevSection,
  });

  @override
  State<TeleprompterKeyboardHandler> createState() =>
      _TeleprompterKeyboardHandlerState();
}

class _TeleprompterKeyboardHandlerState
    extends State<TeleprompterKeyboardHandler> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'TeleprompterKeys');
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _jumpNext() {
    if (widget.onJumpNextSection != null) {
      widget.onJumpNextSection!();
    } else {
      widget.scrollEngine.jumpToNextSection();
    }
  }

  void _jumpPrev() {
    if (widget.onJumpPrevSection != null) {
      widget.onJumpPrevSection!();
    } else {
      widget.scrollEngine.jumpToPrevSection();
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = KeyBinding.normalise(event.logicalKey);

    // Speed keys and tap tempo don't apply to a song following its timing
    final timed = widget.scrollEngine.isTimed;
    switch (widget.shortcuts.actionFor(event)) {
      case ShortcutAction.playPause:
        _playPause();
      case ShortcutAction.scrollUp:
        widget.scrollEngine.scrollByLines(-1);
      case ShortcutAction.scrollDown:
        widget.scrollEngine.scrollByLines(1);
      case ShortcutAction.nextSection:
        _jumpNext();
      case ShortcutAction.prevSection:
        _jumpPrev();
      case ShortcutAction.speedUp:
        if (!timed) widget.syncEngine.adjustSpeed(ScrollConstants.speedStep);
      case ShortcutAction.speedDown:
        if (!timed) widget.syncEngine.adjustSpeed(-ScrollConstants.speedStep);
      case ShortcutAction.fullscreen:
        widget.onToggleFullscreen();
      case ShortcutAction.resetToStart:
        widget.scrollEngine.resetToStart();
      case ShortcutAction.loop:
        widget.scrollEngine.setLoopEnabled(!widget.scrollEngine.loopEnabled);
      case ShortcutAction.mirror:
        widget.onToggleMirror?.call();
      case ShortcutAction.tapTempo:
        if (!timed) widget.onTapTempo?.call();
      case ShortcutAction.nextSong:
        widget.onNextScript?.call();
      case ShortcutAction.edit:
        widget.onEdit?.call();
      case ShortcutAction.prevSong:
        widget.onPrevScript?.call();
      case ShortcutAction.back:
        widget.onBack();
      case null:
        return _handlePedalKey(key);
    }
    return KeyEventResult.handled;
  }

  void _playPause() {
    if (widget.onPlayPauseOverride != null) {
      widget.onPlayPauseOverride!();
    } else {
      widget.syncEngine.togglePlayPause();
    }
  }

  // Foot pedals send PageDown / Enter and PageUp; those keys keep their
  // pedal meaning whatever the shortcuts say
  KeyEventResult _handlePedalKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.pageDown || key == LogicalKeyboardKey.enter) {
      switch (widget.pedalAction) {
        case 'nextSection':
          _jumpNext();
        case 'nextSong':
          widget.onNextScript?.call();
        case 'playPause':
          _playPause();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      switch (widget.pedalAction) {
        case 'nextSection':
          _jumpPrev();
        case 'nextSong':
          widget.onPrevScript?.call();
        case 'playPause':
          _playPause();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: widget.child,
    );
  }
}
