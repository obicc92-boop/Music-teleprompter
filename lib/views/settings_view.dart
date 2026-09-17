import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';
import '../widgets/theme_picker.dart';

export '../utils/constants.dart' show DisplayFont;

enum SettingsSection { display, playback, controls, shortcuts }

class SettingsView extends StatefulWidget {
  final AppSettings settings;

  /// The song whose settings are being edited, or null for the defaults.
  final String? songTitle;
  final bool songHasOwnSettings;
  final void Function(AppSettings) onChanged;
  final VoidCallback onResetSong;
  final VoidCallback onClose;
  final SettingsSection initialSection;

  const SettingsView({
    super.key,
    required this.settings,
    this.songTitle,
    this.songHasOwnSettings = false,
    required this.onChanged,
    required this.onResetSong,
    required this.onClose,
    this.initialSection = SettingsSection.display,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late AppSettings _settings;
  late SettingsSection _section;

  bool get _forSong => widget.songTitle != null;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _section = widget.initialSection;
  }

  @override
  void didUpdateWidget(SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Picks up changes made outside the panel, e.g. Reset to default
    _settings = widget.settings;
  }

  void _update(AppSettings updated) {
    setState(() => _settings = updated);
    widget.onChanged(updated);
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Same size on every tab, so the tabs don't move under the pointer
    final height = (MediaQuery.of(context).size.height - 80).clamp(0.0, 640.0);
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 24,
      shadowColor: Colors.black,
      child: SizedBox(
        width: 588,
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Sidebar(
              selected: _section,
              onSelected: (s) => setState(() => _section = s),
            ),
            _VerticalDivider(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ContentHeader(
          title: switch (_section) {
            SettingsSection.display   => 'Display',
            SettingsSection.playback  => 'Playback',
            SettingsSection.controls  => 'Controls',
            SettingsSection.shortcuts => 'Keyboard Shortcuts',
          },
          onClose: widget.onClose,
        ),
        if (_section == SettingsSection.display || _section == SettingsSection.playback)
          _ScopeBar(
            songTitle: widget.songTitle,
            canReset: widget.songHasOwnSettings,
            onReset: widget.onResetSong,
          ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: switch (_section) {
              SettingsSection.display   => _displayPanel(),
              SettingsSection.playback  => _playbackPanel(),
              SettingsSection.controls  => _controlsPanel(),
              SettingsSection.shortcuts => _shortcutsPanel(),
            },
          ),
        ),
      ],
    );
  }

  // ── Display panel ──────────────────────────────────────────────────────────

  Widget _displayPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingRow(
          label: 'Colour Theme',
          sublabel: 'Background and highlight colour behind the lyrics',
          child: LayoutBuilder(
            builder: (context, constraints) => ThemePicker(
              width: constraints.maxWidth,
              value: _settings.songTheme,
              onChanged: (theme) =>
                  _update(_settings.copyWith(colorTheme: theme.code)),
            ),
          ),
        ),
        _Divider(),
        _SettingRow(
          label: 'Font Size',
          trailing: _ValueBadge('${_settings.fontSize.round()} px'),
          child: _styledSlider(
            value: _settings.fontSize,
            min: AppDimensions.minFontSize,
            max: AppDimensions.maxFontSize,
            onChanged: (v) => _update(_settings.copyWith(fontSize: v)),
          ),
        ),
        _Divider(),
        _SettingRow(
          label: 'Typeface',
          child: Wrap(
            spacing: 8,
            children: DisplayFont.options.map((font) {
              final selected = _settings.displayFont == font.family;
              return _FontChip(
                font: font,
                selected: selected,
                onTap: () => _update(_settings.copyWith(displayFont: font.family)),
              );
            }).toList(),
          ),
        ),
        _Divider(),
        _SettingRow(
          label: 'Text Alignment',
          child: Row(
            children: [
              _Chip(
                label: 'Center',
                selected: !_settings.textAlignLeft,
                onTap: () => _update(_settings.copyWith(textAlignLeft: false)),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'Left',
                selected: _settings.textAlignLeft,
                onTap: () => _update(_settings.copyWith(textAlignLeft: true)),
              ),
            ],
          ),
        ),
        _Divider(),
        _ToggleRow(
          label: 'Active Line Highlight',
          sublabel: 'Brightens the current line and dims the rest',
          value: _settings.showActiveLineHighlight,
          onChanged: (v) => _update(_settings.copyWith(showActiveLineHighlight: v)),
        ),
        _Divider(),
        _SettingRow(
          label: 'Active Line Position',
          trailing: _ValueBadge('${(_settings.activeLineYOffset * 100).round()}% from top'),
          child: _styledSlider(
            value: _settings.activeLineYOffset,
            min: 0.1,
            max: 0.75,
            divisions: 13,
            onChanged: (v) => _update(_settings.copyWith(activeLineYOffset: v)),
          ),
        ),
      ],
    );
  }

  // ── Playback panel ─────────────────────────────────────────────────────────

  Widget _playbackPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingRow(
          label: _forSong ? 'Speed' : 'Default Speed',
          trailing: _ValueBadge(
              ScrollConstants.speedLabel(_settings.scrollSpeedMultiplier)),
          child: _styledSlider(
            value: _settings.scrollSpeedMultiplier,
            min: ScrollConstants.minSpeedMultiplier,
            max: ScrollConstants.maxSpeedMultiplier,
            divisions: ((ScrollConstants.maxSpeedMultiplier -
                        ScrollConstants.minSpeedMultiplier) /
                    ScrollConstants.speedStep)
                .round(),
            onChanged: (v) => _update(_settings.copyWith(
                scrollSpeedMultiplier: (v * 100).round() / 100)),
          ),
        ),
        _Divider(),
        _ToggleRow(
          label: 'Auto-advance to next song',
          sublabel: _forSong
              ? 'Loads the next setlist song when the current one ends · all songs'
              : 'Loads the next setlist song when the current one ends',
          value: _settings.autoAdvance,
          onChanged: (v) => _update(_settings.copyWith(autoAdvance: v)),
        ),
      ],
    );
  }

  // ── Controls panel ─────────────────────────────────────────────────────────

  Widget _controlsPanel() {
    const actions = [
      ('nextSection', 'Next Section'),
      ('nextSong',    'Next Song'),
      ('playPause',   'Play / Pause'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingRow(
          label: 'Foot Pedal — Forward Action',
          sublabel: 'What PageDown / Enter does during performance',
          child: Wrap(
            spacing: 8,
            children: actions.map((e) {
              final (value, label) = e;
              return _Chip(
                label: label,
                selected: _settings.pedalAction == value,
                onTap: () => _update(_settings.copyWith(pedalAction: value)),
              );
            }).toList(),
          ),
        ),
        _Divider(),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: _HintBox(
            lines: [
              'PageDown / Enter  →  forward action',
              'PageUp  →  backward action (previous section or song)',
              'Compatible with AirTurn, PageFlip, and most HID pedals',
            ],
          ),
        ),
      ],
    );
  }

  // ── Shortcuts panel ────────────────────────────────────────────────────────

  Widget _shortcutsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShortcutGroup(
          title: 'Playback',
          rows: const [
            ('Space', 'Play / pause'),
            ('+ / −', 'Speed up / slow down'),
            ('T', 'Tap tempo'),
            ('R', 'Reset to start'),
            ('L', 'Toggle loop section'),
          ],
        ),
        const SizedBox(height: 16),
        _ShortcutGroup(
          title: 'Navigation',
          rows: const [
            ('↑ / ↓', 'Scroll up / down'),
            ('→ / ←', 'Next / previous section'),
            ('N', 'Next song'),
            ('P', 'Previous song'),
          ],
        ),
        const SizedBox(height: 16),
        _ShortcutGroup(
          title: 'Display',
          rows: const [
            ('F', 'Toggle fullscreen'),
            ('M', 'Toggle mirror mode'),
            ('Esc', 'Back to setlist'),
          ],
        ),
        const SizedBox(height: 16),
        _ShortcutGroup(
          title: 'Foot Pedal (configurable in Controls)',
          rows: const [
            ('PageDown / Enter', 'Forward action'),
            ('PageUp', 'Backward action'),
          ],
        ),
        const SizedBox(height: 12),
        const _HintBox(lines: [
          'Foot pedal action is set in the Controls tab',
          'Compatible with AirTurn, PageFlip, and most HID pedals',
        ]),
      ],
    );
  }

  // ── Shared slider ──────────────────────────────────────────────────────────

  Widget _styledSlider({
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        activeTrackColor: AppColors.sliderActive,
        inactiveTrackColor: AppColors.sliderInactive,
        thumbColor: AppColors.sliderActive,
        overlayColor: AppColors.sliderActive.withValues(alpha: 0.15),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}

// ── Sidebar ────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final SettingsSection selected;
  final ValueChanged<SettingsSection> onSelected;

  const _Sidebar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      color: AppColors.sidebar,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 36), // align with header height
          _SidebarItem(
            icon: Icons.text_fields_rounded,
            label: 'Display',
            selected: selected == SettingsSection.display,
            onTap: () => onSelected(SettingsSection.display),
          ),
          _SidebarItem(
            icon: Icons.tune_rounded,
            label: 'Playback',
            selected: selected == SettingsSection.playback,
            onTap: () => onSelected(SettingsSection.playback),
          ),
          _SidebarItem(
            icon: Icons.keyboard_rounded,
            label: 'Controls',
            selected: selected == SettingsSection.controls,
            onTap: () => onSelected(SettingsSection.controls),
          ),
          _SidebarItem(
            icon: Icons.keyboard_alt_outlined,
            label: 'Shortcuts',
            selected: selected == SettingsSection.shortcuts,
            onTap: () => onSelected(SettingsSection.shortcuts),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.uiText;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.accentText : color),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTextStyles.ui,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Content chrome ─────────────────────────────────────────────────────────

class _ContentHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _ContentHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 14),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTextStyles.ui,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.uiHint,
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }
}

// ── Scope bar — whose settings the panel is editing ────────────────────────

class _ScopeBar extends StatelessWidget {
  final String? songTitle;
  final bool canReset;
  final VoidCallback onReset;

  const _ScopeBar({
    required this.songTitle,
    required this.canReset,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final forSong = songTitle != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            forSong ? Icons.music_note_rounded : Icons.tune_rounded,
            size: 15,
            color: forSong ? AppColors.accent : AppColors.uiHint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forSong ? songTitle! : 'Default settings',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.ui,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  forSong
                      ? 'Speed and display changes are saved for this song'
                      : 'Used by every song that has no settings of its own',
                  style: const TextStyle(
                    fontFamily: AppTextStyles.ui,
                    fontSize: 10,
                    color: AppColors.uiHint,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (forSong) ...[
            const SizedBox(width: 10),
            Tooltip(
              message: canReset
                  ? 'Use the default settings for this song'
                  : 'This song already uses the default settings',
              child: InkWell(
                onTap: canReset ? onReset : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: canReset
                          ? AppColors.accent
                          : AppColors.uiHint.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'Reset to default',
                    style: TextStyle(
                      fontFamily: AppTextStyles.ui,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: canReset
                          ? AppColors.accent
                          : AppColors.uiHint.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Setting rows ───────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  final String label;
  final String? sublabel;
  final Widget? trailing;
  final Widget child;

  const _SettingRow({
    required this.label,
    this.sublabel,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (sublabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sublabel!,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.ui,
                          fontSize: 10,
                          color: AppColors.uiHint,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    this.sublabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sublabel!,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.ui,
                      fontSize: 10,
                      color: AppColors.uiHint,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Small reusable atoms ───────────────────────────────────────────────────

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      color: AppColors.hairline,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.hairline,
    );
  }
}

class _ValueBadge extends StatelessWidget {
  final String text;
  const _ValueBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTextStyles.mono,
          fontSize: 11,
          color: AppColors.uiHint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentSoft
              : AppColors.surfaceSelected,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTextStyles.ui,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? AppColors.accentText : AppColors.uiText,
          ),
        ),
      ),
    );
  }
}

class _FontChip extends StatelessWidget {
  final DisplayFont font;
  final bool selected;
  final VoidCallback onTap;

  const _FontChip({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentSoft
              : AppColors.surfaceSelected,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                fontFamily: font.family,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.accentText : AppColors.uiText,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              font.label,
              style: TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 9,
                letterSpacing: 0.5,
                color: selected ? AppColors.accent : AppColors.uiHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutGroup extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  const _ShortcutGroup({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: AppTextStyles.ui,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.uiHint,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Container(height: 1, color: AppColors.surface),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppColors.uiHint.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Text(
                          rows[i].$1,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.mono,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.uiText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rows[i].$2,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.ui,
                            fontSize: 12,
                            color: AppColors.uiText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HintBox extends StatelessWidget {
  final List<String> lines;
  const _HintBox({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('·  ',
                          style: TextStyle(
                              color: AppColors.uiHint, fontSize: 11)),
                      Expanded(
                        child: Text(
                          l,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.ui,
                            fontSize: 11,
                            color: AppColors.uiHint,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}
