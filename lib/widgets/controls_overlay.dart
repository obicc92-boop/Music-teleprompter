import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/sync_engine.dart';
import '../engine/scroll_engine.dart';
import '../utils/constants.dart';
import 'bpm_indicator.dart';

class ControlsOverlay extends StatefulWidget {
  final SyncEngine syncEngine;
  final ScrollEngine scrollEngine;
  final VoidCallback onFullscreen;
  final VoidCallback onMirrorToggle;
  final VoidCallback onSettings;
  final VoidCallback onBack;
  final VoidCallback? onNextScript;
  final VoidCallback? onPrevScript;
  final String? setlistPosition;
  final bool isMirrorMode;
  final bool isFullscreen;

  const ControlsOverlay({
    super.key,
    required this.syncEngine,
    required this.scrollEngine,
    required this.onFullscreen,
    required this.onMirrorToggle,
    required this.onSettings,
    required this.onBack,
    this.onNextScript,
    this.onPrevScript,
    this.setlistPosition,
    required this.isMirrorMode,
    required this.isFullscreen,
  });

  @override
  State<ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<ControlsOverlay>
    with SingleTickerProviderStateMixin {
  Timer? _hideTimer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(
      Duration(seconds: AppDimensions.controlsHideDelay.round()),
      _hide,
    );
  }

  void _show() {
    _fadeController.forward();
    _scheduleHide();
  }

  void _hide() {
    if (widget.syncEngine.isPlaying) {
      _fadeController.reverse();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => _show(),
      child: GestureDetector(
        onTap: _show,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar() {
    return ListenableBuilder(
      listenable: widget.syncEngine,
      builder: (context, _) {
        final state = widget.syncEngine.state;
        return Container(
          height: AppDimensions.controlsHeight + 16,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [AppColors.controlBackground, Colors.transparent],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _backButton(),
              if (widget.onPrevScript != null) ...[
                const SizedBox(width: 6),
                _iconButton(
                  icon: Icons.skip_previous_rounded,
                  size: 20,
                  color: AppColors.sectionHeader,
                  onTap: widget.onPrevScript!,
                  tooltip: 'Previous song',
                ),
              ],
              if (widget.setlistPosition != null) ...[
                const SizedBox(width: 6),
                Text(
                  widget.setlistPosition!,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 11,
                    color: AppColors.sectionHeader,
                  ),
                ),
              ],
              if (widget.onNextScript != null) ...[
                const SizedBox(width: 6),
                _iconButton(
                  icon: Icons.skip_next_rounded,
                  size: 20,
                  color: AppColors.accent,
                  onTap: widget.onNextScript!,
                  tooltip: 'Next song',
                ),
              ],
              const SizedBox(width: 16),
              _playPauseButton(state),
              const SizedBox(width: 20),
              _speedControl(state),
              const Spacer(),
              BpmIndicator(
                beatStream: widget.syncEngine.beatStream,
                bpm: state.bpm,
                isVoiceActive: state.isVoiceActive,
                voiceEnergy: state.voiceEnergy,
              ),
              const Spacer(),
              _loopButton(),
              const SizedBox(width: 12),
              _mirrorButton(),
              const SizedBox(width: 12),
              _settingsButton(),
              const SizedBox(width: 12),
              _fullscreenButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _playPauseButton(SyncEngineState state) {
    final isPlaying = state.playState == PlayState.playing;
    return _iconButton(
      icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 32,
      color: AppColors.accent,
      onTap: () => widget.syncEngine.togglePlayPause(),
      tooltip: isPlaying ? 'Pause (Space)' : 'Play (Space)',
    );
  }

  Widget _speedControl(SyncEngineState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconButton(
          icon: Icons.remove,
          size: 18,
          onTap: () => widget.syncEngine.adjustSpeed(-0.1),
          tooltip: 'Slow down (↓)',
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: AppColors.sliderActive,
              inactiveTrackColor: AppColors.sliderInactive,
              thumbColor: AppColors.sliderActive,
              overlayColor: AppColors.sliderActive.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: state.manualMultiplier.clamp(
                ScrollConstants.minSpeedMultiplier,
                ScrollConstants.maxSpeedMultiplier,
              ),
              min: ScrollConstants.minSpeedMultiplier,
              max: ScrollConstants.maxSpeedMultiplier,
              onChanged: (v) => widget.syncEngine.setManualMultiplier(v),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _iconButton(
          icon: Icons.add,
          size: 18,
          onTap: () => widget.syncEngine.adjustSpeed(0.1),
          tooltip: 'Speed up (↑)',
        ),
        const SizedBox(width: 8),
        Text(
          '${state.manualMultiplier.toStringAsFixed(1)}x',
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 12,
            color: AppColors.sectionHeader,
          ),
        ),
      ],
    );
  }

  Widget _backButton() {
    return _iconButton(
      icon: Icons.arrow_back_rounded,
      color: AppColors.sectionHeader,
      onTap: widget.onBack,
      tooltip: 'Back to editor (ESC)',
    );
  }

  Widget _loopButton() {
    return ListenableBuilder(
      listenable: widget.scrollEngine,
      builder: (context, _) {
        final enabled = widget.scrollEngine.loopEnabled;
        return _iconButton(
          icon: Icons.repeat_rounded,
          color: enabled ? AppColors.loopMarker : AppColors.sectionHeader,
          onTap: () => widget.scrollEngine.setLoopEnabled(!enabled),
          tooltip: 'Loop section (L)',
        );
      },
    );
  }

  Widget _mirrorButton() {
    return _iconButton(
      icon: Icons.flip_rounded,
      color: widget.isMirrorMode ? AppColors.accent : AppColors.sectionHeader,
      onTap: widget.onMirrorToggle,
      tooltip: 'Mirror mode (M)',
    );
  }

  Widget _settingsButton() {
    return _iconButton(
      icon: Icons.tune_rounded,
      onTap: widget.onSettings,
      tooltip: 'Settings',
    );
  }

  Widget _fullscreenButton() {
    return _iconButton(
      icon: widget.isFullscreen
          ? Icons.fullscreen_exit_rounded
          : Icons.fullscreen_rounded,
      onTap: widget.onFullscreen,
      tooltip: widget.isFullscreen ? 'Exit fullscreen (F)' : 'Fullscreen (F)',
    );
  }

  Widget _iconButton({
    required IconData icon,
    double size = 22,
    Color color = AppColors.inactiveLine,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: size, color: color),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }
}
