import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../engine/sync_engine.dart';
import '../engine/scroll_engine.dart';
import '../models/script.dart';
import '../utils/constants.dart';
import '../utils/keyboard_handler.dart';
import '../widgets/controls_overlay.dart';
import '../widgets/mirror_transform.dart';
import '../widgets/script_line_widget.dart';
import '../services/settings_service.dart';

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
  bool _isFullscreen = false;
  bool _isMirrorMode = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _isMirrorMode = widget.settings.mirrorMode;

    _scrollEngine = ScrollEngine(syncEngine: widget.syncEngine);
    _scrollEngine.attach(this);
    _scrollEngine.setScript(widget.script, _effectiveLineHeight);
    _scrollEngine.start();
  }

  double get _effectiveLineHeight => _settings.fontSize * 2.0;

  @override
  void dispose() {
    _scrollEngine.dispose();
    super.dispose();
  }

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    setState(() => _isFullscreen = next);
    await windowManager.setFullScreen(next);
  }

  void _toggleMirror() {
    setState(() => _isMirrorMode = !_isMirrorMode);
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
      onToggleMirror: _toggleMirror,
      onBack: _handleBack,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: MirrorTransform(
          enabled: _isMirrorMode,
          child: Stack(
            children: [
              _buildCanvas(),
              ControlsOverlay(
                syncEngine: widget.syncEngine,
                scrollEngine: _scrollEngine,
                onFullscreen: _toggleFullscreen,
                onMirrorToggle: _toggleMirror,
                onSettings: _openSettings,
                onBack: _handleBack,
                onNextScript: widget.onNextScript,
                onPrevScript: widget.onPrevScript,
                setlistPosition: widget.setlistPosition,
                isMirrorMode: _isMirrorMode,
                isFullscreen: _isFullscreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: _scrollEngine,
        builder: (context, _) {
          final screenHeight = MediaQuery.of(context).size.height;
          final anchorY = screenHeight * AppDimensions.activeLineYOffset;
          final lineHeight = _effectiveLineHeight;
          final activeIdx = _scrollEngine.activeLineIndex;
          final pixelOffset = _scrollEngine.pixelOffset;
          final lines = widget.script.allLines;

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
                  left: 0,
                  right: 0,
                  top: y,
                  height: lineHeight,
                  child: Center(
                    child: ScriptLineWidget(
                      line: lines[i],
                      proximity: proximity,
                      fontSize: _settings.fontSize,
                      karaokeEnabled: _settings.karaokeMode,
                      isLoopBoundary: isLoopBoundary,
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
