import 'dart:async';
import 'package:flutter/material.dart';
import '../engine/sync_engine.dart';
import '../engine/scroll_engine.dart';
import '../models/song_theme.dart';
import '../services/chord_transposer.dart';
import '../utils/constants.dart';

class ControlsOverlay extends StatefulWidget {
  final SyncEngine syncEngine;
  final ScrollEngine scrollEngine;
  final VoidCallback onFullscreen;
  final VoidCallback onSettings;
  final VoidCallback onFormatLyrics;
  final VoidCallback onBack;
  final VoidCallback? onNextScript;
  final VoidCallback? onPrevScript;
  final VoidCallback onToggleMirror;
  final VoidCallback onTapTempo;
  final VoidCallback onSetDuration;
  final VoidCallback? onUnloadAudio;
  final VoidCallback? onUnloadLrc;
  final bool hasLrc;
  final String? lrcFileName;
  final String? setlistPosition;
  final bool isFullscreen;
  final bool isMirrored;
  final String songTitle;
  final bool hasAudio;
  final String? audioFileName;
  final double audioVolume;
  final ValueChanged<double> onVolumeChanged;
  final bool hasChords;
  final int transposeSteps;
  final ValueChanged<int> onTransposeChanged;
  final bool cueMode;
  final VoidCallback onToggleCueMode;
  final String? remoteUrl;
  final SongTheme? songTheme;
  final ValueChanged<SongTheme>? onThemeChanged;
  final VoidCallback? onMoveToDisplay;
  final bool isOnSecondDisplay;

  const ControlsOverlay({
    super.key,
    required this.syncEngine,
    required this.scrollEngine,
    required this.onFullscreen,
    required this.onSettings,
    required this.onFormatLyrics,
    required this.onBack,
    this.onNextScript,
    this.onPrevScript,
    required this.onToggleMirror,
    required this.onTapTempo,
    required this.onSetDuration,
    this.onUnloadAudio,
    this.onUnloadLrc,
    this.hasLrc = false,
    this.lrcFileName,
    this.setlistPosition,
    required this.isFullscreen,
    required this.isMirrored,
    required this.songTitle,
    required this.hasAudio,
    this.audioFileName,
    required this.audioVolume,
    required this.onVolumeChanged,
    this.hasChords = false,
    this.transposeSteps = 0,
    required this.onTransposeChanged,
    this.cueMode = false,
    required this.onToggleCueMode,
    this.remoteUrl,
    this.songTheme,
    this.onThemeChanged,
    this.onMoveToDisplay,
    this.isOnSecondDisplay = false,
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
            if (widget.onNextScript != null)
              Positioned(
                right: 16,
                bottom: AppDimensions.controlsHeight + 8,
                child: _nextSongButton(),
              ),
            if (widget.onPrevScript != null)
              Positioned(
                left: 16,
                bottom: AppDimensions.controlsHeight + 8,
                child: _prevSongButton(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _nextSongButton() {
    return Tooltip(
      message: 'Next song  [N]',
      child: Opacity(
        opacity: 0.75,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onNextScript,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'NEXT',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.skip_next_rounded,
                      size: 18, color: AppColors.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _prevSongButton() {
    return Tooltip(
      message: 'Previous song  [P]',
      child: Opacity(
        opacity: 0.75,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPrevScript,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.sectionHeader.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.skip_previous_rounded,
                      size: 18, color: AppColors.sectionHeader),
                  const SizedBox(width: 4),
                  Text(
                    'PREV',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sectionHeader,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _backButton(),
              if (widget.setlistPosition != null) ...[
                const SizedBox(width: 10),
                Text(
                  widget.setlistPosition!,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 12,
                    color: AppColors.sectionHeader,
                  ),
                ),
              ],
              const SizedBox(width: 16),
              _playPauseButton(state),
              const SizedBox(width: 20),
              _speedControl(state),
              Expanded(
                child: Center(
                  child: Text(
                    widget.songTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.activeLine,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              _loopButton(),
              if (widget.onMoveToDisplay != null) ...[
                const SizedBox(width: 12),
                _moveToDisplayButton(),
              ],
              const SizedBox(width: 12),
              _themeButton(),
              const SizedBox(width: 12),
              _remoteButton(),
              const SizedBox(width: 12),
              _cueModeButton(),
              const SizedBox(width: 12),
              _mirrorButton(),
              const SizedBox(width: 12),
              _tapTempoButton(),
              if (widget.hasChords) ...[
                const SizedBox(width: 12),
                _transposeControl(),
              ],
              const SizedBox(width: 12),
              _durationButton(),
              _audioButton(),
              if (widget.hasAudio) ...[
                const SizedBox(width: 4),
                _volumeControl(),
                const SizedBox(width: 8),
                _lrcButton(),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 12),
              _iconButton(
                icon: Icons.format_paint_rounded,
                onTap: widget.onFormatLyrics,
                tooltip: 'Format lyrics',
              ),
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
          tooltip: 'Slow down (−)',
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: AppColors.sliderActive,
              inactiveTrackColor: AppColors.sliderInactive,
              thumbColor: AppColors.sliderActive,
              overlayColor:
                  AppColors.sliderActive.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: state.manualMultiplier.clamp(
                ScrollConstants.minSpeedMultiplier,
                ScrollConstants.maxSpeedMultiplier,
              ),
              min: ScrollConstants.minSpeedMultiplier,
              max: ScrollConstants.maxSpeedMultiplier,
              onChanged: (v) =>
                  widget.syncEngine.setManualMultiplier(v),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _iconButton(
          icon: Icons.add,
          size: 18,
          onTap: () => widget.syncEngine.adjustSpeed(0.1),
          tooltip: 'Speed up (+)',
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

  Widget _backButton() => _iconButton(
        icon: Icons.arrow_back_rounded,
        color: AppColors.sectionHeader,
        onTap: widget.onBack,
        tooltip: 'Back (ESC)',
      );

  Widget _loopButton() {
    return ListenableBuilder(
      listenable: widget.scrollEngine,
      builder: (context, _) {
        final enabled = widget.scrollEngine.loopEnabled;
        return _iconButton(
          icon: Icons.repeat_rounded,
          color: enabled ? AppColors.loopMarker : AppColors.sectionHeader,
          onTap: () =>
              widget.scrollEngine.setLoopEnabled(!enabled),
          tooltip: 'Loop section (L)',
        );
      },
    );
  }

  Widget _mirrorButton() => _iconButton(
        icon: Icons.flip_rounded,
        color: widget.isMirrored ? AppColors.accent : AppColors.inactiveLine,
        onTap: widget.onToggleMirror,
        tooltip: 'Mirror flip (M)',
      );

  Widget _tapTempoButton() => _iconButton(
        icon: Icons.touch_app_rounded,
        onTap: widget.onTapTempo,
        tooltip: 'Tap tempo (T) — tap 4+ times to set speed',
      );

  Widget _durationButton() => _iconButton(
        icon: Icons.timer_outlined,
        onTap: widget.onSetDuration,
        tooltip: 'Set song duration — auto-calculates scroll speed',
      );

  Widget _lrcButton() {
    if (!widget.hasLrc) return const SizedBox.shrink();
    return Tooltip(
      message: 'Synced lyrics: ${widget.lrcFileName ?? "loaded"}  (right-click to remove)',
      child: GestureDetector(
        onSecondaryTap: widget.onUnloadLrc,
        child: _iconButton(
          icon: Icons.lyrics_rounded,
          color: AppColors.accent,
          onTap: null,
          tooltip: null,
        ),
      ),
    );
  }

  Widget _audioButton() {
    if (!widget.hasAudio) return const SizedBox.shrink();
    return Tooltip(
      message: 'Audio: ${widget.audioFileName ?? "loaded"}  (right-click to remove)',
      child: GestureDetector(
        onSecondaryTap: widget.onUnloadAudio,
        child: _iconButton(
          icon: Icons.music_note_rounded,
          color: AppColors.accent,
          onTap: null,
          tooltip: null,
        ),
      ),
    );
  }

  Widget _volumeControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          widget.audioVolume == 0
              ? Icons.volume_off_rounded
              : widget.audioVolume < 0.5
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded,
          size: 16,
          color: AppColors.sectionHeader,
        ),
        const SizedBox(width: 2),
        SizedBox(
          width: 72,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: AppColors.accent.withValues(alpha: 0.7),
              inactiveTrackColor: AppColors.sliderInactive,
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: widget.audioVolume,
              min: 0.0,
              max: 1.0,
              onChanged: widget.onVolumeChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingsButton() => _iconButton(
        icon: Icons.tune_rounded,
        onTap: widget.onSettings,
        tooltip: 'Settings',
      );

  Widget _fullscreenButton() => _iconButton(
        icon: widget.isFullscreen
            ? Icons.fullscreen_exit_rounded
            : Icons.fullscreen_rounded,
        onTap: widget.onFullscreen,
        tooltip: widget.isFullscreen
            ? 'Exit fullscreen (F)'
            : 'Fullscreen (F)',
      );

  Widget _themeButton() {
    final theme = widget.songTheme;
    return Tooltip(
      message: 'Song colour theme',
      child: InkWell(
        onTap: widget.onThemeChanged != null ? _showThemePicker : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: theme?.accent ?? AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.sectionHeader.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showThemePicker() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Song Colour Theme',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.activeLine,
          ),
        ),
        content: SizedBox(
          width: 340,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: SongTheme.presets.map((t) {
              final selected = widget.songTheme?.id == t.id;
              return GestureDetector(
                onTap: () {
                  widget.onThemeChanged!(t);
                  Navigator.of(ctx).pop();
                },
                child: Container(
                  width: 96,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? t.accent
                          : AppColors.sectionHeader.withValues(alpha: 0.2),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: t.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.label,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: t.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                color: AppColors.sectionHeader,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _remoteButton() {
    final active = widget.remoteUrl != null;
    return Tooltip(
      message: active ? 'Remote: ${widget.remoteUrl}' : 'Remote control unavailable',
      child: _iconButton(
        icon: Icons.wifi_rounded,
        color: active ? AppColors.accent : AppColors.inactiveLine,
        onTap: active
            ? () => _showRemoteDialog(widget.remoteUrl!)
            : null,
        tooltip: null,
      ),
    );
  }

  void _showRemoteDialog(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Phone Remote Control',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.activeLine,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Scan with your phone or open the address below\n(must be on the same Wi-Fi network)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 12,
                color: AppColors.sectionHeader,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: Image.network(
                'https://api.qrserver.com/v1/create-qr-code/'
                '?size=200x200&margin=0&data=${Uri.encodeComponent(url)}',
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                errorBuilder: (ctx, err, stack) => const Center(
                  child: Icon(Icons.qr_code_2_rounded,
                      size: 48, color: AppColors.sectionHeader),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                url,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Close',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                color: AppColors.sectionHeader,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moveToDisplayButton() => _iconButton(
        icon: _isOnSecondDisplay
            ? Icons.monitor_rounded
            : Icons.cast_rounded,
        color: _isOnSecondDisplay ? AppColors.accent : AppColors.inactiveLine,
        onTap: widget.onMoveToDisplay,
        tooltip: _isOnSecondDisplay
            ? 'Return to main display'
            : 'Move to second display',
      );

  bool get _isOnSecondDisplay => widget.isOnSecondDisplay;

  Widget _cueModeButton() => _iconButton(
        icon: Icons.touch_app_outlined,
        color: widget.cueMode ? AppColors.accent : AppColors.inactiveLine,
        onTap: widget.onToggleCueMode,
        tooltip: widget.cueMode ? 'Cue mode ON — Space advances one line' : 'Cue mode OFF — tap to enable',
      );

  Widget _transposeControl() {
    final label = ChordTransposer.offsetLabel(widget.transposeSteps);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconButton(
          icon: Icons.arrow_drop_down_rounded,
          size: 20,
          onTap: () => widget.onTransposeChanged(widget.transposeSteps - 1),
          tooltip: 'Transpose down one semitone',
        ),
        SizedBox(
          width: 36,
          child: Text(
            label == '0' ? '♩' : label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: label == '0' ? AppColors.sectionHeader : AppColors.accent,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _iconButton(
          icon: Icons.arrow_drop_up_rounded,
          size: 20,
          onTap: () => widget.onTransposeChanged(widget.transposeSteps + 1),
          tooltip: 'Transpose up one semitone',
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    double size = 22,
    Color color = AppColors.inactiveLine,
    required VoidCallback? onTap,
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
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }
}
