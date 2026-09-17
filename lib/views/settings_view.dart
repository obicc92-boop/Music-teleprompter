import 'package:flutter/material.dart';
import '../engine/sync_engine.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';

export '../utils/constants.dart' show DisplayFont;

enum _Section { display, playback, controls, shortcuts }

class SettingsView extends StatefulWidget {
  final AppSettings settings;
  final SyncEngine syncEngine;
  final void Function(AppSettings) onChanged;
  final VoidCallback onClose;

  const SettingsView({
    super.key,
    required this.settings,
    required this.syncEngine,
    required this.onChanged,
    required this.onClose,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late AppSettings _settings;
  _Section _section = _Section.display;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _update(AppSettings updated) {
    setState(() => _settings = updated);
    SettingsService().save(updated);
    widget.onChanged(updated);
    widget.syncEngine.setManualMultiplier(updated.scrollSpeedMultiplier);
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height - 80;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 560),
        child: IntrinsicHeight(
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
            _Section.display   => 'Display',
            _Section.playback  => 'Playback',
            _Section.controls  => 'Controls',
            _Section.shortcuts => 'Keyboard Shortcuts',
          },
          onClose: widget.onClose,
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: switch (_section) {
              _Section.display   => _displayPanel(),
              _Section.playback  => _playbackPanel(),
              _Section.controls  => _controlsPanel(),
              _Section.shortcuts => _shortcutsPanel(),
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
          label: 'Default Speed',
          trailing: _ValueBadge('${_settings.scrollSpeedMultiplier.toStringAsFixed(1)}×'),
          child: _styledSlider(
            value: _settings.scrollSpeedMultiplier,
            min: ScrollConstants.minSpeedMultiplier,
            max: ScrollConstants.maxSpeedMultiplier,
            onChanged: (v) => _update(_settings.copyWith(scrollSpeedMultiplier: v)),
          ),
        ),
        _Divider(),
        _ToggleRow(
          label: 'Auto-advance to next song',
          sublabel: 'Loads the next setlist song when the current one ends',
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
              'PageUp  →  always goes back one section',
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
            ('Space', 'Play / Pause'),
            ('+ / −', 'Speed up / Slow down'),
            ('T', 'Tap Tempo'),
            ('R', 'Reset to start'),
            ('L', 'Toggle loop section'),
          ],
        ),
        const SizedBox(height: 16),
        _ShortcutGroup(
          title: 'Navigation',
          rows: const [
            ('↑ / ↓', 'Scroll up / Scroll down'),
            ('→ / ←', 'Next / Previous section'),
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
  final _Section selected;
  final ValueChanged<_Section> onSelected;

  const _Sidebar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 36), // align with header height
          _SidebarItem(
            icon: Icons.text_fields_rounded,
            label: 'Display',
            selected: selected == _Section.display,
            onTap: () => onSelected(_Section.display),
          ),
          _SidebarItem(
            icon: Icons.tune_rounded,
            label: 'Playback',
            selected: selected == _Section.playback,
            onTap: () => onSelected(_Section.playback),
          ),
          _SidebarItem(
            icon: Icons.keyboard_rounded,
            label: 'Controls',
            selected: selected == _Section.controls,
            onTap: () => onSelected(_Section.controls),
          ),
          _SidebarItem(
            icon: Icons.keyboard_alt_outlined,
            label: 'Shortcuts',
            selected: selected == _Section.shortcuts,
            onTap: () => onSelected(_Section.shortcuts),
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
    final color = selected ? AppColors.accent : AppColors.sectionHeader;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: color,
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
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.activeLine,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.sectionHeader,
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
                        fontFamily: AppTextStyles.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inactiveLine,
                      ),
                    ),
                    if (sublabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sublabel!,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 10,
                          color: AppColors.sectionHeader,
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
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inactiveLine,
                  ),
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sublabel!,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 10,
                      color: AppColors.sectionHeader,
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
            activeThumbColor: AppColors.accent,
            activeTrackColor: AppColors.accent.withValues(alpha: 0.35),
            inactiveThumbColor: AppColors.sectionHeader,
            inactiveTrackColor: AppColors.surfaceElevated,
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
      color: AppColors.surfaceElevated,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.surfaceElevated,
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
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 11,
          color: AppColors.sectionHeader,
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
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? AppColors.accent : AppColors.inactiveLine,
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
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
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
                color: selected ? AppColors.accent : AppColors.inactiveLine,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              font.label,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 9,
                letterSpacing: 0.5,
                color: selected ? AppColors.accent : AppColors.sectionHeader,
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
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.sectionHeader,
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
                          border: Border.all(color: AppColors.sectionHeader.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Text(
                          rows[i].$1,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inactiveLine,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rows[i].$2,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 12,
                            color: AppColors.inactiveLine,
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
                              color: AppColors.sectionHeader, fontSize: 11)),
                      Expanded(
                        child: Text(
                          l,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 11,
                            color: AppColors.sectionHeader,
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
