import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/sync_engine.dart';
import '../engine/scroll_engine.dart';

// Pedal action values — match AppSettings.pedalAction strings
// 'nextSection' : PageDown = next section, PageUp = prev section
// 'nextSong'    : PageDown = next song, PageUp = prev song
// 'playPause'   : PageDown / Enter = play/pause toggle

class TeleprompterKeyboardHandler extends StatefulWidget {
  final Widget child;
  final SyncEngine syncEngine;
  final ScrollEngine scrollEngine;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onBack;
  final VoidCallback? onNextScript;
  final VoidCallback? onPrevScript;
  final String pedalAction;

  const TeleprompterKeyboardHandler({
    super.key,
    required this.child,
    required this.syncEngine,
    required this.scrollEngine,
    required this.onToggleFullscreen,
    required this.onBack,
    this.onNextScript,
    this.onPrevScript,
    this.pedalAction = 'nextSection',
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

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // SPACE — play/pause
    if (key == LogicalKeyboardKey.space) {
      widget.syncEngine.togglePlayPause();
      return KeyEventResult.handled;
    }

    // UP — speed up
    if (key == LogicalKeyboardKey.arrowUp) {
      widget.syncEngine.adjustSpeed(0.1);
      return KeyEventResult.handled;
    }

    // DOWN — slow down
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.syncEngine.adjustSpeed(-0.1);
      return KeyEventResult.handled;
    }

    // RIGHT — next section
    if (key == LogicalKeyboardKey.arrowRight) {
      widget.scrollEngine.jumpToNextSection();
      return KeyEventResult.handled;
    }

    // LEFT — prev section
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.scrollEngine.jumpToPrevSection();
      return KeyEventResult.handled;
    }

    // F — fullscreen
    if (key == LogicalKeyboardKey.keyF) {
      widget.onToggleFullscreen();
      return KeyEventResult.handled;
    }

    // R — reset to start
    if (key == LogicalKeyboardKey.keyR) {
      widget.scrollEngine.resetToStart();
      return KeyEventResult.handled;
    }

    // L — toggle loop
    if (key == LogicalKeyboardKey.keyL) {
      widget.scrollEngine.setLoopEnabled(!widget.scrollEngine.loopEnabled);
      return KeyEventResult.handled;
    }

    // N — next song in setlist
    if (key == LogicalKeyboardKey.keyN) {
      widget.onNextScript?.call();
      return KeyEventResult.handled;
    }

    // P — previous song in setlist
    if (key == LogicalKeyboardKey.keyP) {
      widget.onPrevScript?.call();
      return KeyEventResult.handled;
    }

    // ESC — back to editor
    if (key == LogicalKeyboardKey.escape) {
      widget.onBack();
      return KeyEventResult.handled;
    }

    // Foot pedal mappings (PageDown = forward, PageUp = back, Enter = alternate)
    if (key == LogicalKeyboardKey.pageDown || key == LogicalKeyboardKey.enter) {
      switch (widget.pedalAction) {
        case 'nextSection':
          widget.scrollEngine.jumpToNextSection();
        case 'nextSong':
          widget.onNextScript?.call();
        case 'playPause':
          widget.syncEngine.togglePlayPause();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.pageUp) {
      switch (widget.pedalAction) {
        case 'nextSection':
          widget.scrollEngine.jumpToPrevSection();
        case 'nextSong':
          widget.onPrevScript?.call();
        case 'playPause':
          widget.syncEngine.togglePlayPause();
      }
      return KeyEventResult.handled;
    }

    // + / = — font size up
    if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.numpadAdd) {
      return KeyEventResult.ignored; // delegated to parent
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
