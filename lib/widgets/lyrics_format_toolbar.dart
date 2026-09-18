import 'package:flutter/material.dart';
import '../models/song_theme.dart';
import '../utils/constants.dart';
import 'colour_sliders.dart';
import 'formatted_text_controller.dart';

/// Colour, size and bold for the words selected in the lyrics editor.
/// Clicking here never takes focus from the lyrics, so the selection stays.
class LyricsFormatToolbar extends StatelessWidget {
  final FormattedTextController controller;

  /// Lets the lyrics field treat taps here as its own (see TextField.groupId).
  final Object tapGroup;

  /// Explains what to select, until something is.
  final bool showHint;

  /// Offers a Section button: not every keyboard has square brackets.
  final bool sections;

  const LyricsFormatToolbar({
    super.key,
    required this.controller,
    required this.tapGroup,
    this.showHint = true,
    this.sections = true,
  });

  /// Colours that stand out on a dark stage screen.
  static const palette = [
    0xFFFF6B35, // orange, the app's own
    0xFFEF5350, // red
    0xFFFFD700, // gold
    0xFF66BB6A, // green
    0xFF4FC3F7, // sky
    0xFF7C9CFF, // blue
    0xFFCE93D8, // lilac
    0xFFFF80AB, // pink
  ];

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: tapGroup,
      child: ExcludeFocus(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final active = controller.targetWords != null;
            final look = controller.targetLook;
            final colour = look?.colorValue;
            final scale = look?.fontSizeScale ?? 1.0;
            return Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 8,
              children: [
                if (sections) ...[
                  _SectionButton(controller: controller),
                  _gap(),
                ],
                _Tool(
                  tooltip: 'Bold (Ctrl+B)',
                  enabled: active,
                  on: look?.bold ?? false,
                  onTap: controller.toggleBold,
                  child: const Text(
                    'B',
                    style: TextStyle(
                      fontFamily: AppTextStyles.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _gap(),
                _Tool(
                  tooltip: 'Smaller (Ctrl+[)',
                  enabled: active && scale > 0.8,
                  onTap: () => controller.stepFontSize(-1),
                  child: const Text(
                    'A−',
                    style: TextStyle(
                        fontFamily: AppTextStyles.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${(scale * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTextStyles.mono,
                      fontSize: 12,
                      color: active ? AppColors.uiText : AppColors.uiMuted,
                    ),
                  ),
                ),
                _Tool(
                  tooltip: 'Bigger (Ctrl+])',
                  enabled: active && scale < 2.0,
                  onTap: () => controller.stepFontSize(1),
                  child: const Text(
                    'A+',
                    style: TextStyle(
                        fontFamily: AppTextStyles.ui,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                _gap(),
                for (final value in palette)
                  _Swatch(
                    colour: Color(value),
                    tooltip: 'Colour',
                    enabled: active,
                    selected: colour == value,
                    onTap: () => controller.style(colorValue: value),
                  ),
                _Swatch(
                  colour: colour != null && !palette.contains(colour)
                      ? Color(colour)
                      : null,
                  tooltip: 'Any colour…',
                  enabled: active,
                  selected: colour != null && !palette.contains(colour),
                  onTap: () => _pickColour(context, colour),
                ),
                _gap(),
                _Tool(
                  tooltip: 'Back to plain lyrics (Ctrl+\\)',
                  enabled: active && look != null,
                  onTap: controller.clearStyle,
                  child: const Icon(Icons.format_clear_rounded, size: 18),
                ),
                if (!active && showHint)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Text(
                      'Click a word, or select a few, to colour or resize them',
                      style: TextStyle(
                        fontFamily: AppTextStyles.ui,
                        fontSize: 12,
                        color: AppColors.uiHint,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _gap() => Container(
        width: 1,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: AppColors.border,
      );

  Future<void> _pickColour(BuildContext context, int? current) async {
    var colour = HSVColor.fromColor(
        current != null ? Color(current) : const Color(0xFFFF6B35));
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Word colour'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Text(
                    'Sing it loud',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colour.toColor(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ColourSliders(
                  value: colour,
                  onChanged: (c) => setState(() => colour = c),
                ),
                if (SongTheme.contrast(colour.toColor(), const Color(0xFF0A0A0A)) < 3)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'This colour will be hard to see on a dark stage screen.',
                      style: TextStyle(
                        fontFamily: AppTextStyles.ui,
                        fontSize: 12,
                        color: Color(0xFFFFB74D),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, colour.toColor()),
              child: const Text('Use this colour'),
            ),
          ],
        ),
      ),
    );
    if (picked != null) controller.style(colorValue: picked.toARGB32());
  }
}

/// Drops a section line in at the caret, so nobody has to type brackets.
class _SectionButton extends StatelessWidget {
  final FormattedTextController controller;
  const _SectionButton({required this.controller});

  static const _names = [
    'Intro',
    'Verse',
    'Pre-Chorus',
    'Chorus',
    'Bridge',
    'Solo',
    'Outro',
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Add a section line here (Verse, Chorus…)',
      position: PopupMenuPosition.under,
      onSelected: (name) async {
        if (name == '…') {
          final custom = await _askName(context);
          if (custom == null || custom.trim().isEmpty) return;
          controller.insertSection(custom.trim());
        } else {
          controller.insertSection(
              name == 'Verse' ? controller.nextVerseName() : name);
        }
      },
      itemBuilder: (_) => [
        for (final name in _names)
          PopupMenuItem(
            value: name,
            height: 40,
            child: Text(name == 'Verse' ? controller.nextVerseName() : name),
          ),
        const PopupMenuDivider(height: 8),
        const PopupMenuItem(
            value: '…', height: 40, child: Text('Another name…')),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_add_outlined, size: 16, color: AppColors.uiText),
            SizedBox(width: 6),
            Text(
              'Section',
              style: TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 16, color: AppColors.uiHint),
          ],
        ),
      ),
    );
  }

  Future<String?> _askName(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Section name'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. Breakdown'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  final String tooltip;
  final bool enabled;
  final bool on;
  final VoidCallback onTap;
  final Widget child;

  const _Tool({
    required this.tooltip,
    required this.enabled,
    this.on = false,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: on ? AppColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: on ? AppColors.accent : AppColors.border,
              ),
            ),
            child: IconTheme(
              data: IconThemeData(
                color: !enabled
                    ? AppColors.uiMuted
                    : on
                        ? AppColors.accentText
                        : AppColors.uiText,
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: !enabled
                      ? AppColors.uiMuted
                      : on
                          ? AppColors.accentText
                          : AppColors.textPrimary,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color? colour; // null: any colour, not yet picked
  final String tooltip;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.colour,
    required this.tooltip,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colour = this.colour;
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colour,
                  gradient: colour == null
                      ? const SweepGradient(colors: [
                          Color(0xFFFF3B30),
                          Color(0xFFFFCC00),
                          Color(0xFF34C759),
                          Color(0xFF00C7BE),
                          Color(0xFF007AFF),
                          Color(0xFFAF52DE),
                          Color(0xFFFF3B30),
                        ])
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
