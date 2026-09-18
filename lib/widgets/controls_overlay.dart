import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../engine/sync_engine.dart';
import '../engine/scroll_engine.dart';
import '../models/song_theme.dart';
import 'theme_picker.dart';
import '../utils/app_platform.dart';
import '../services/chord_transposer.dart';
import '../utils/constants.dart';

enum _MoreAction {
  loop,
  tapTempo,
  duration,
  transpose,
  cueMode,
  mirror,
  theme,
  edit,
  remote,
  display,
  removeAudio,
  recordTiming,
  removeTiming,
}

class ControlsOverlay extends StatefulWidget {
  final SyncEngine syncEngine;
  final ScrollEngine scrollEngine;
  final VoidCallback onPlayPause;
  /// Null where the app is always full screen (phones and tablets).
  final VoidCallback? onFullscreen;
  final VoidCallback onSettings;
  /// Opens the song in the editor; null where editing isn't possible.
  final VoidCallback? onEdit;
  final VoidCallback onBack;
  final VoidCallback? onNextScript;
  final VoidCallback? onPrevScript;
  final VoidCallback onToggleMirror;
  final VoidCallback onTapTempo;
  final VoidCallback onSetDuration;
  final VoidCallback? onUnloadAudio;

  /// Where a timed song's timing comes from, or null if it scrolls at speed.
  final String? timingLabel;
  final VoidCallback onRecordTiming;
  final VoidCallback? onRemoveTiming;
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
  final SongTheme? defaultTheme;
  final bool songHasOwnTheme;
  final ValueChanged<SongTheme>? onThemeChanged;
  final VoidCallback? onThemeReset;
  final VoidCallback? onMoveToDisplay;
  final bool isOnSecondDisplay;

  const ControlsOverlay({
    super.key,
    required this.syncEngine,
    required this.scrollEngine,
    required this.onPlayPause,
    required this.onFullscreen,
    required this.onSettings,
    this.onEdit,
    required this.onBack,
    this.onNextScript,
    this.onPrevScript,
    required this.onToggleMirror,
    required this.onTapTempo,
    required this.onSetDuration,
    this.onUnloadAudio,
    this.timingLabel,
    required this.onRecordTiming,
    this.onRemoveTiming,
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
    this.defaultTheme,
    this.songHasOwnTheme = false,
    this.onThemeChanged,
    this.onThemeReset,
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
      // Not opaque: the lyrics underneath must still get double-clicks and
      // finger drags
      opaque: false,
      onHover: (_) => _show(),
      // A Listener, not a tap gesture: a gesture here would win every click
      // over the lyrics beneath (a line being edited, a word double-clicked)
      child: Listener(
        onPointerDown: (_) => _show(),
        behavior: HitTestBehavior.translucent,
        // Hidden controls ignore taps, so tapping the screen to bring them
        // back can't also press a button (e.g. NEXT) by accident.
        child: AnimatedBuilder(
          animation: _fadeController,
          builder: (context, child) => IgnorePointer(
            ignoring: _fadeController.value == 0,
            child: child,
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBar(),
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
                      fontFamily: AppTextStyles.ui,
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
                  color: AppColors.uiHint.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.skip_previous_rounded,
                      size: 18, color: AppColors.uiHint),
                  const SizedBox(width: 4),
                  Text(
                    'PREV',
                    style: TextStyle(
                      fontFamily: AppTextStyles.ui,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.uiHint,
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

  // Only what's needed mid-song lives in the bar; everything else is under
  // More, so the bar fits even the smallest window.
  Widget _buildBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) return _buildPhoneBar();
        final compact = constraints.maxWidth < 960;
        final gap = compact ? 4.0 : 8.0;
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
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 32, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _backButton(),
                  if (widget.setlistPosition != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      widget.setlistPosition!,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.mono,
                        fontSize: 12,
                        color: AppColors.uiHint,
                      ),
                    ),
                  ],
                  SizedBox(width: compact ? 8 : 16),
                  _playPauseButton(state),
                  SizedBox(width: compact ? 8 : 20),
                  widget.timingLabel != null
                      ? _timingChip()
                      : _speedControl(state, sliderWidth: compact ? 72 : 120),
                  const SizedBox(width: 12),
                  Expanded(child: _songTitle()),
                  const SizedBox(width: 12),
                  if (widget.hasAudio) ...[
                    _volumeControl(sliderWidth: compact ? 56 : 72),
                    SizedBox(width: gap),
                  ],
                  if (widget.onEdit != null) ...[
                    _editButton(),
                    SizedBox(width: gap),
                  ],
                  _loopButton(),
                  SizedBox(width: gap),
                  _moreButton(),
                  SizedBox(width: gap),
                  _settingsButton(),
                  if (widget.onFullscreen != null) ...[
                    SizedBox(width: gap),
                    _fullscreenButton(),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // A phone held upright: play and speed stay in the bar, loop moves to More
  Widget _buildPhoneBar() {
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              _backButton(),
              const SizedBox(width: 4),
              _playPauseButton(state),
              const SizedBox(width: 8),
              widget.timingLabel != null
                  ? _timingChip()
                  : _phoneSpeedControl(state),
              const Spacer(),
              _moreButton(),
              _settingsButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _phoneSpeedControl(SyncEngineState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconButton(
          icon: Icons.remove,
          size: 20,
          onTap: () => widget.syncEngine.adjustSpeed(-ScrollConstants.speedStep),
          tooltip: 'Slower',
        ),
        SizedBox(
          width: 52,
          child: Text(
            ScrollConstants.speedLabel(state.manualMultiplier),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTextStyles.mono,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        _iconButton(
          icon: Icons.add,
          size: 20,
          onTap: () => widget.syncEngine.adjustSpeed(ScrollConstants.speedStep),
          tooltip: 'Faster',
        ),
      ],
    );
  }

  Widget _songTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            widget.songTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTextStyles.ui,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (widget.hasAudio) ...[
          const SizedBox(width: 8),
          _statusIcon(Icons.music_note_rounded,
              'Backing track: ${widget.audioFileName ?? "loaded"}'),
        ],
      ],
    );
  }

  Widget _statusIcon(IconData icon, String tooltip) => Tooltip(
        message: tooltip,
        child: Icon(icon, size: 15, color: AppColors.accent),
      );

  Widget _playPauseButton(SyncEngineState state) {
    final isPlaying = state.playState == PlayState.playing;
    return _iconButton(
      icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 32,
      color: AppColors.accent,
      onTap: widget.onPlayPause,
      tooltip: isPlaying ? 'Pause (Space)' : 'Play (Space)',
    );
  }

  Widget _speedControl(SyncEngineState state, {required double sliderWidth}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconButton(
          icon: Icons.remove,
          size: 18,
          onTap: () => widget.syncEngine.adjustSpeed(-ScrollConstants.speedStep),
          tooltip: 'Slow down (−)',
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: sliderWidth,
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
        const SizedBox(width: 4),
        _iconButton(
          icon: Icons.add,
          size: 18,
          onTap: () => widget.syncEngine.adjustSpeed(ScrollConstants.speedStep),
          tooltip: 'Speed up (+)',
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 48, // fixed so the bar doesn't shift as the number changes
          child: Text(
            ScrollConstants.speedLabel(state.manualMultiplier),
            style: const TextStyle(
              fontFamily: AppTextStyles.mono,
              fontSize: 12,
              color: AppColors.uiText,
            ),
          ),
        ),
      ],
    );
  }

  // A timed song follows its timing, so a song clock replaces the speed control
  Widget _timingChip() {
    return Tooltip(
      message: '${widget.timingLabel}\n'
          'If the band drifts: press ↓ as a line starts, or → at a new section',
      child: ListenableBuilder(
        listenable: widget.scrollEngine,
        builder: (context, _) {
          final seconds = widget.scrollEngine.clockSeconds.floor();
          final clock =
              '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.graphic_eq_rounded,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40, // fixed so the bar doesn't shift as time passes
                  child: Text(
                    clock,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.mono,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Text(
                  'TIMED',
                  style: TextStyle(
                    fontFamily: AppTextStyles.ui,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _backButton() => _iconButton(
        icon: Icons.arrow_back_rounded,
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
          color: enabled ? AppColors.loopMarker : AppColors.uiText,
          onTap: () =>
              widget.scrollEngine.setLoopEnabled(!enabled),
          tooltip: enabled ? 'Loop section: on (L)' : 'Loop section (L)',
        );
      },
    );
  }

  Widget _volumeControl({required double sliderWidth}) {
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
          color: AppColors.uiText,
        ),
        const SizedBox(width: 2),
        SizedBox(
          width: sliderWidth,
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

  Widget _editButton() => _iconButton(
        icon: Icons.edit_rounded,
        size: 20,
        onTap: widget.onEdit,
        tooltip: 'Edit lyrics (E)',
      );

  Widget _settingsButton() => _iconButton(
        icon: Icons.tune_rounded,
        onTap: widget.onSettings,
        tooltip: 'Settings',
      );

  Widget _fullscreenButton() => _iconButton(
        icon: widget.isFullscreen
            ? Icons.fullscreen_exit_rounded
            : Icons.fullscreen_rounded,
        onTap: widget.onFullscreen ?? () {},
        tooltip: widget.isFullscreen
            ? 'Exit fullscreen (F)'
            : 'Fullscreen (F)',
      );

  // ── More menu ──────────────────────────────────────────────────────────────

  Widget _moreButton() {
    return PopupMenuButton<_MoreAction>(
      tooltip: 'More',
      position: PopupMenuPosition.over,
      onSelected: _onMoreSelected,
      itemBuilder: (context) => _moreItems(),
      child: Padding(
        padding: EdgeInsets.all(AppPlatform.isTouch ? 10 : 6),
        child: const Icon(Icons.more_horiz_rounded,
            size: 22, color: AppColors.uiText),
      ),
    );
  }

  List<PopupMenuEntry<_MoreAction>> _moreItems() {
    final transposeLabel = ChordTransposer.offsetLabel(widget.transposeSteps);
    final theme = widget.songTheme ?? SongTheme.defaultTheme;
    final timed = widget.timingLabel != null;
    final phoneBar = MediaQuery.sizeOf(context).width < 600;
    return [
      if (phoneBar) ...[
        _menuItem(_MoreAction.loop, Icons.repeat_rounded, 'Loop section',
            checked: widget.scrollEngine.loopEnabled),
        const PopupMenuDivider(height: 8),
      ],
      _menuItem(_MoreAction.recordTiming, Icons.radio_button_checked_rounded,
          timed ? 'Record timing again…' : 'Record timing…'),
      // Speed tools don't apply to a song that follows its timing
      if (!timed) ...[
        _menuItem(_MoreAction.tapTempo, Icons.speed_rounded, 'Tap tempo…',
            shortcut: 'T'),
        _menuItem(_MoreAction.duration, Icons.timer_outlined,
            'Set song duration…'),
      ],
      if (widget.onRemoveTiming != null)
        _menuItem(_MoreAction.removeTiming, Icons.timer_off_outlined,
            'Remove timing…'),
      if (widget.hasChords)
        _menuItem(_MoreAction.transpose, Icons.swap_vert_rounded, 'Transpose…',
            shortcut: transposeLabel == '0' ? null : transposeLabel),
      const PopupMenuDivider(height: 8),
      _menuItem(_MoreAction.cueMode, Icons.format_line_spacing_rounded,
          'Cue mode: line by line',
          checked: widget.cueMode),
      _menuItem(_MoreAction.mirror, Icons.flip_rounded, 'Mirror text',
          shortcut: 'M', checked: widget.isMirrored),
      const PopupMenuDivider(height: 8),
      _menuItem(
        _MoreAction.theme,
        Icons.palette_outlined,
        'Colour theme…',
        trailing: Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.background,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.uiHint, width: 1),
          ),
          child: Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: theme.accent, shape: BoxShape.circle),
          ),
        ),
        enabled: widget.onThemeChanged != null,
      ),
      if (widget.onEdit != null)
        _menuItem(_MoreAction.edit, Icons.edit_rounded, 'Edit lyrics…',
            shortcut: 'E'),
      _menuItem(
        _MoreAction.remote,
        Icons.wifi_rounded,
        widget.remoteUrl != null ? 'Phone remote…' : 'Phone remote unavailable',
        enabled: widget.remoteUrl != null,
      ),
      if (widget.onMoveToDisplay != null)
        _menuItem(
          _MoreAction.display,
          widget.isOnSecondDisplay ? Icons.monitor_rounded : Icons.cast_rounded,
          widget.isOnSecondDisplay
              ? 'Return to main display'
              : 'Move to second display',
        ),
      if (widget.hasAudio) ...[
        const PopupMenuDivider(height: 8),
        _menuItem(_MoreAction.removeAudio, Icons.music_off_rounded,
            'Remove backing track…'),
      ],
    ];
  }

  PopupMenuItem<_MoreAction> _menuItem(
    _MoreAction action,
    IconData icon,
    String label, {
    String? shortcut,
    Widget? trailing,
    bool checked = false,
    bool enabled = true,
  }) {
    final touch = AppPlatform.isTouch;
    if (touch) shortcut = null; // no keyboard to press them on
    return PopupMenuItem<_MoreAction>(
      value: action,
      enabled: enabled,
      height: touch ? 48 : 40,
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: checked
                  ? AppColors.accent
                  : enabled
                      ? AppColors.uiText
                      : AppColors.uiHint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: touch ? 14 : 12,
                color: enabled ? AppColors.textPrimary : AppColors.uiHint,
              ),
            ),
          ),
          if (shortcut != null) ...[
            const SizedBox(width: 16),
            Text(
              shortcut,
              style: const TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 11,
                color: AppColors.uiHint,
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 16),
            trailing,
          ],
          if (checked) ...[
            const SizedBox(width: 12),
            const Icon(Icons.check_rounded, size: 16, color: AppColors.accent),
          ],
        ],
      ),
    );
  }

  void _onMoreSelected(_MoreAction action) {
    switch (action) {
      case _MoreAction.loop:
        widget.scrollEngine.setLoopEnabled(!widget.scrollEngine.loopEnabled);
      case _MoreAction.tapTempo:
        _showTapTempoDialog();
      case _MoreAction.duration:
        widget.onSetDuration();
      case _MoreAction.transpose:
        _showTransposeDialog();
      case _MoreAction.cueMode:
        widget.onToggleCueMode();
      case _MoreAction.mirror:
        widget.onToggleMirror();
      case _MoreAction.theme:
        _showThemePicker();
      case _MoreAction.edit:
        widget.onEdit?.call();
      case _MoreAction.remote:
        if (widget.remoteUrl != null) _showRemoteDialog(widget.remoteUrl!);
      case _MoreAction.display:
        widget.onMoveToDisplay?.call();
      case _MoreAction.removeAudio:
        _confirmRemove(
          title: 'Remove backing track?',
          message: 'The backing track is removed from "${widget.songTitle}". '
              'The audio file itself is not deleted.',
          onConfirm: widget.onUnloadAudio,
        );
      case _MoreAction.recordTiming:
        widget.onRecordTiming();
      case _MoreAction.removeTiming:
        _confirmRemove(
          title: 'Remove timing?',
          message: '"${widget.songTitle}" goes back to scrolling at its speed. '
              'The lyrics are kept.',
          onConfirm: widget.onRemoveTiming,
        );
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  static const _dialogTitleStyle = TextStyle(
    fontFamily: AppTextStyles.ui,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const _dialogBodyStyle = TextStyle(
    fontFamily: AppTextStyles.ui,
    fontSize: 12,
    color: AppColors.uiText,
    height: 1.5,
  );

  Widget _dialogButton(String label, VoidCallback onPressed,
      {bool primary = false}) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTextStyles.ui,
          fontWeight: primary ? FontWeight.w700 : FontWeight.w400,
          color: primary ? AppColors.accent : AppColors.uiHint,
        ),
      ),
    );
  }

  Future<void> _confirmRemove({
    required String title,
    required String message,
    required VoidCallback? onConfirm,
  }) async {
    if (onConfirm == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: _dialogTitleStyle),
        content: SizedBox(
          width: 340,
          child: Text(message, style: _dialogBodyStyle),
        ),
        actions: [
          _dialogButton('Cancel', () => Navigator.of(ctx).pop(false)),
          _dialogButton('Remove', () => Navigator.of(ctx).pop(true),
              primary: true),
        ],
      ),
    );
    if (confirmed == true) onConfirm();
  }

  void _showTapTempoDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tap tempo', style: _dialogTitleStyle),
        content: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.keyT ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              widget.onTapTempo();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tap along with the beat 4 or more times (or press T). '
                  'The scroll speed follows your taps.',
                  textAlign: TextAlign.center,
                  style: _dialogBodyStyle,
                ),
                const SizedBox(height: 20),
                Material(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: widget.onTapTempo,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 110,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.accent, width: 1.5),
                      ),
                      child: const Text(
                        'TAP',
                        style: TextStyle(
                          fontFamily: AppTextStyles.ui,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListenableBuilder(
                  listenable: widget.syncEngine,
                  builder: (context, _) => Text(
                    'Speed  ${ScrollConstants.speedLabel(widget.syncEngine.state.manualMultiplier)}',
                    style: const TextStyle(
                      fontFamily: AppTextStyles.mono,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          _dialogButton('Done', () => Navigator.of(ctx).pop(), primary: true),
        ],
      ),
    );
  }

  void _showTransposeDialog() {
    var steps = widget.transposeSteps;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void change(int to) {
            final normalized = ((to % 12) + 12) % 12;
            setDialogState(() => steps = normalized);
            widget.onTransposeChanged(normalized);
          }

          final label = ChordTransposer.offsetLabel(steps);
          return AlertDialog(
            title: const Text('Transpose chords', style: _dialogTitleStyle),
            content: SizedBox(
              width: 280,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _iconButton(
                    icon: Icons.remove_rounded,
                    size: 24,
                    onTap: () => change(steps - 1),
                    tooltip: 'Down one semitone',
                  ),
                  SizedBox(
                    width: 140,
                    child: Text(
                      label == '0' ? 'Original key' : '$label semitones',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTextStyles.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: label == '0'
                            ? AppColors.uiText
                            : AppColors.accent,
                      ),
                    ),
                  ),
                  _iconButton(
                    icon: Icons.add_rounded,
                    size: 24,
                    onTap: () => change(steps + 1),
                    tooltip: 'Up one semitone',
                  ),
                ],
              ),
            ),
            actions: [
              _dialogButton('Reset', () => change(0)),
              _dialogButton('Done', () => Navigator.of(ctx).pop(),
                  primary: true),
            ],
          );
        },
      ),
    );
  }

  void _showThemePicker() {
    final onChanged = widget.onThemeChanged;
    if (onChanged == null) return;
    final theme = widget.songTheme ?? SongTheme.defaultTheme;
    showDialog<void>(
      context: context,
      // Light, so the lyrics behind show each colour as it's picked
      barrierColor: const Color(0x33000000),
      builder: (ctx) => SongThemeDialog(
        theme: theme,
        defaultTheme: widget.defaultTheme ?? SongTheme.defaultTheme,
        hasOwnTheme: widget.songHasOwnTheme,
        onChanged: onChanged,
        onReset: widget.onThemeReset,
      ),
    );
  }

  void _showRemoteDialog(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Phone remote', style: _dialogTitleStyle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Scan with your phone or open the address below\n(must be on the same Wi-Fi network)',
              textAlign: TextAlign.center,
              style: _dialogBodyStyle,
            ),
            const SizedBox(height: 20),
            // Drawn locally: works without internet at the venue and doesn't
            // send the address to an outside service.
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: QrImageView(
                data: url,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSelected,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                url,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTextStyles.mono,
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
          _dialogButton('Close', () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    double size = 22,
    Color color = AppColors.uiText,
    required VoidCallback? onTap,
    String? tooltip,
  }) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        // Fingers need a bigger target than a pointer
        padding: EdgeInsets.all(AppPlatform.isTouch ? 10 : 6),
        child: Icon(icon, size: size, color: color),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }
}
