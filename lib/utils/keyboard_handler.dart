import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine/sync_engine.dart';
import '../engine/scroll_engine.dart';

class TeleprompterKeyboardHandler extends StatefulWidget {
  final Widget child;
  final SyncEngine syncEngine;
  final ScrollEngine scrollEngine;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleMirror;
  final VoidCallback onBack;

  const TeleprompterKeyboardHandler({
    super.key,
    required this.child,
    required this.syncEngine,
    required this.scrollEngine,
    required this.onToggleFullscreen,
    required this.onToggleMirror,
    required this.onBack,
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

    // M — mirror
    if (key == LogicalKeyboardKey.keyM) {
      widget.onToggleMirror();
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

    // ESC — back to editor
    if (key == LogicalKeyboardKey.escape) {
      widget.onBack();
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
