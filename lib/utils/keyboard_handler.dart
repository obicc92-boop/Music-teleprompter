import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/sync_engine.dart';
import '../engine/scroll_engine.dart';
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
  final VoidCallback? onPlayPauseOverride;
  final String pedalAction;

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
    this.onPlayPauseOverride,
    this.pedalAction = 'nextSection',
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
    _focusNode = FocusNode(debugLabel: 'TeleprompterKeys');
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      if (widget.onPlayPauseOverride != null) {
        widget.onPlayPauseOverride!();
      } else {
        widget.syncEngine.togglePlayPause();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      widget.scrollEngine.scrollByLines(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.scrollEngine.scrollByLines(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _jumpNext();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _jumpPrev();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.numpadAdd) {
      widget.syncEngine.adjustSpeed(ScrollConstants.keyboardSpeedStep);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
      widget.syncEngine.adjustSpeed(-ScrollConstants.keyboardSpeedStep);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      widget.onToggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      widget.scrollEngine.resetToStart();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyL) {
      widget.scrollEngine.setLoopEnabled(!widget.scrollEngine.loopEnabled);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      widget.onToggleMirror?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyT) {
      widget.onTapTempo?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyN) {
      widget.onNextScript?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyP) {
      widget.onPrevScript?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.onBack();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.pageDown || key == LogicalKeyboardKey.enter) {
      switch (widget.pedalAction) {
        case 'nextSection':
          _jumpNext();
        case 'nextSong':
          widget.onNextScript?.call();
        case 'playPause':
          widget.onPlayPauseOverride != null
              ? widget.onPlayPauseOverride!()
              : widget.syncEngine.togglePlayPause();
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
          widget.onPlayPauseOverride != null
              ? widget.onPlayPauseOverride!()
              : widget.syncEngine.togglePlayPause();
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
