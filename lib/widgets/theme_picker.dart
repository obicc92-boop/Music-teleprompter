import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/song_theme.dart';
import '../utils/constants.dart';

/// Colour themes as small lyrics screens to pick from, plus a colour editor
/// for Custom. Every change is reported straight away, so the lyrics behind
/// can show it.
class ThemePicker extends StatefulWidget {
  final SongTheme value;
  final ValueChanged<SongTheme> onChanged;

  /// Width to lay the tiles out in (a dialog can't measure it).
  final double width;

  const ThemePicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.width,
  });

  @override
  State<ThemePicker> createState() => _ThemePickerState();
}

enum _Target { background, accent }

class _ThemePickerState extends State<ThemePicker> {
  _Target _target = _Target.background;
  late HSVColor _background;
  late HSVColor _accent;
  final _hex = TextEditingController();
  final _hexFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _takeColours();
  }

  @override
  void didUpdateWidget(ThemePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Colours dragged here keep their hue even at no strength or brightness;
    // only colours changed elsewhere are taken over
    if (widget.value.background.toARGB32() !=
            _background.toColor().toARGB32() ||
        widget.value.accent.toARGB32() != _accent.toColor().toARGB32()) {
      _takeColours();
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  void _takeColours() {
    _background = HSVColor.fromColor(widget.value.background);
    _accent = HSVColor.fromColor(widget.value.accent);
    _showHex();
  }

  HSVColor get _editing =>
      _target == _Target.background ? _background : _accent;

  void _showHex() {
    if (!_hexFocus.hasFocus) _hex.text = SongTheme.hex(_editing.toColor());
  }

  void _pickCustom() {
    if (widget.value.isCustom) return;
    // Starts from the colours already on screen
    widget.onChanged(
      SongTheme.custom(
        background: widget.value.background,
        accent: widget.value.accent,
      ),
    );
  }

  void _edit(HSVColor colour) {
    setState(() {
      if (_target == _Target.background) {
        _background = colour;
      } else {
        _accent = colour;
      }
      _showHex();
    });
    widget.onChanged(
      SongTheme.custom(
        background: _background.toColor(),
        accent: _accent.toColor(),
      ),
    );
  }

  void _selectTarget(_Target target) {
    setState(() {
      _target = target;
      _hex.text = SongTheme.hex(_editing.toColor());
    });
  }

  @override
  Widget build(BuildContext context) {
    const columns = 4;
    const gap = 10.0;
    final tileWidth = (widget.width - gap * (columns - 1)) / columns;
    final value = widget.value;

    return SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: gap,
            runSpacing: 12,
            children: [
              for (final theme in SongTheme.presets)
                _ThemeTile(
                  theme: theme,
                  label: theme.label,
                  width: tileWidth,
                  selected: value == theme,
                  onTap: () => widget.onChanged(theme),
                ),
              _ThemeTile(
                theme: value.isCustom ? value : null,
                label: 'Custom',
                width: tileWidth,
                selected: value.isCustom,
                onTap: _pickCustom,
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: value.isCustom
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _customEditor(value),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _customEditor(SongTheme theme) {
    final hsv = _editing;
    final colour = hsv.toColor();
    // Strength is easier to judge on a colour that isn't nearly black
    final visible = hsv.withValue(math.max(hsv.value, 0.45));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Preview(theme: theme),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ColourWell(
                  label: 'Background',
                  colour: theme.background,
                  selected: _target == _Target.background,
                  onTap: () => _selectTarget(_Target.background),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ColourWell(
                  label: 'Highlight',
                  colour: theme.accent,
                  selected: _target == _Target.accent,
                  onTap: () => _selectTarget(_Target.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sliderRow(
            'Colour',
            GradientSlider(
              colours: [
                for (var h = 0; h <= 360; h += 60)
                  HSVColor.fromAHSV(1, h % 360.0, 1, 1).toColor(),
              ],
              value: hsv.hue / 360,
              thumb: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
              onChanged: (v) => _edit(hsv.withHue(math.min(v * 360, 359.9))),
            ),
          ),
          _sliderRow(
            'Strength',
            GradientSlider(
              colours: [
                visible.withSaturation(0).toColor(),
                visible.withSaturation(1).toColor(),
              ],
              value: hsv.saturation,
              thumb: colour,
              onChanged: (v) => _edit(hsv.withSaturation(v)),
            ),
          ),
          // Squared, so the dark shades a background needs get most of the
          // slider instead of its first sliver
          _sliderRow(
            'Brightness',
            GradientSlider(
              colours: [
                for (final p in const [0.0, 0.25, 0.5, 0.75, 1.0])
                  hsv.withValue(p * p).toColor(),
              ],
              value: math.sqrt(hsv.value),
              thumb: colour,
              onChanged: (v) => _edit(hsv.withValue(v * v)),
            ),
          ),
          const SizedBox(height: 6),
          _sliderRow(
            'Hex code',
            Align(alignment: Alignment.centerLeft, child: _hexField()),
          ),
          for (final warning in theme.readabilityWarnings)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFFFFB74D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.ui,
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.uiText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sliderRow(String label, Widget control) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.uiText,
              ),
            ),
          ),
          Expanded(child: control),
        ],
      ),
    );
  }

  Widget _hexField() {
    return Container(
      width: 104,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Text(
            '#',
            style: TextStyle(
              fontFamily: AppTextStyles.mono,
              fontSize: 13,
              color: AppColors.uiHint,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _hex,
              focusNode: _hexFocus,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
              ],
              style: const TextStyle(
                fontFamily: AppTextStyles.mono,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration.collapsed(
                hintText: 'RRGGBB',
              ).copyWith(counterText: ''),
              onChanged: (text) {
                final colour = SongTheme.parseHex(text);
                if (colour != null) _edit(HSVColor.fromColor(colour));
              },
              onSubmitted: (_) => _hexFocus.unfocus(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

/// A theme drawn as a tiny lyrics screen: section name, current line, next line.
class _ThemeTile extends StatelessWidget {
  final SongTheme? theme; // null: Custom before any colours were picked
  final String label;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.theme,
    required this.label,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = this.theme;
    final tile = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 58,
                decoration: BoxDecoration(
                  color: theme?.background ?? AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: theme == null
                      ? const _RainbowRing()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _bar(18, 3, theme.accent),
                            const SizedBox(height: 5),
                            _bar(width * 0.46, 5, theme.text),
                            const SizedBox(height: 5),
                            _bar(width * 0.32, 4, theme.nearText),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTextStyles.ui,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.textPrimary : AppColors.uiText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return theme == null
        ? Tooltip(message: 'Pick your own colours', child: tile)
        : tile;
  }

  static Widget _bar(double width, double height, Color colour) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: colour,
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

class _RainbowRing extends StatelessWidget {
  const _RainbowRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFFFF3B30),
            Color(0xFFFFCC00),
            Color(0xFF34C759),
            Color(0xFF00C7BE),
            Color(0xFF007AFF),
            Color(0xFFAF52DE),
            Color(0xFFFF3B30),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// A few lyric lines in the chosen colours, as they'll look on stage.
class _Preview extends StatelessWidget {
  final SongTheme theme;
  const _Preview({required this.theme});

  @override
  Widget build(BuildContext context) {
    const font = AppTextStyles.fontFamily;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 104,
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'CHORUS',
            style: TextStyle(
              fontFamily: font,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: theme.accent,
            ),
          ),
          const SizedBox(height: 8),
          _fit(
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: font,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                ),
                children: [
                  const TextSpan(text: 'Sing it '),
                  TextSpan(
                    text: 'loud',
                    style: TextStyle(color: theme.accent),
                  ),
                  const TextSpan(text: ' tonight'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          _fit(
            Text(
              'Hold on, hold on',
              style: TextStyle(
                fontFamily: font,
                fontSize: 14,
                color: theme.nearText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shrinks a line rather than wrapping it in a narrow panel
  static Widget _fit(Widget line) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: FittedBox(fit: BoxFit.scaleDown, child: line),
  );
}

class _ColourWell extends StatelessWidget {
  final String label;
  final Color colour;
  final bool selected;
  final VoidCallback onTap;

  const _ColourWell({
    required this.label,
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '#${SongTheme.hex(colour)}',
                      style: const TextStyle(
                        fontFamily: AppTextStyles.mono,
                        fontSize: 11,
                        color: AppColors.uiHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A slider whose track shows the colours it moves through.
class GradientSlider extends StatelessWidget {
  final List<Color> colours;
  final double value; // 0–1
  final Color thumb;
  final ValueChanged<double> onChanged;

  const GradientSlider({
    super.key,
    required this.colours,
    required this.value,
    required this.thumb,
    required this.onChanged,
  });

  static const _inset = 11.0;

  void _moveTo(BuildContext context, Offset position) {
    final width = context.size?.width ?? 1;
    onChanged(((position.dx - _inset) / (width - 2 * _inset)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _moveTo(context, d.localPosition),
        onHorizontalDragStart: (d) => _moveTo(context, d.localPosition),
        onHorizontalDragUpdate: (d) => _moveTo(context, d.localPosition),
        child: SizedBox(
          height: 26,
          width: double.infinity,
          child: CustomPaint(
            painter: _GradientSliderPainter(
              colours: colours,
              value: value.clamp(0.0, 1.0),
              thumb: thumb,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientSliderPainter extends CustomPainter {
  final List<Color> colours;
  final double value;
  final Color thumb;

  _GradientSliderPainter({
    required this.colours,
    required this.value,
    required this.thumb,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final rect = Rect.fromLTWH(0, cy - 5, size.width, 10);
    final track = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    canvas.drawRRect(
      track,
      Paint()..shader = LinearGradient(colors: colours).createShader(rect),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.1),
    );

    const inset = GradientSlider._inset;
    final centre = Offset(inset + value * (size.width - 2 * inset), cy);
    canvas.drawCircle(
      centre.translate(0, 1),
      10,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(centre, 9.5, Paint()..color = Colors.white);
    canvas.drawCircle(centre, 7, Paint()..color = thumb);
  }

  @override
  bool shouldRepaint(_GradientSliderPainter old) =>
      old.value != value || old.thumb != thumb || old.colours != colours;
}

/// The in-song dialog: picks this song's colours, or goes back to the default.
class SongThemeDialog extends StatefulWidget {
  final SongTheme theme;
  final SongTheme defaultTheme;
  final bool hasOwnTheme;
  final ValueChanged<SongTheme> onChanged;
  final VoidCallback? onReset;

  const SongThemeDialog({
    super.key,
    required this.theme,
    required this.defaultTheme,
    required this.hasOwnTheme,
    required this.onChanged,
    this.onReset,
  });

  @override
  State<SongThemeDialog> createState() => _SongThemeDialogState();
}

class _SongThemeDialogState extends State<SongThemeDialog> {
  late SongTheme _theme = widget.theme;
  late bool _ownTheme = widget.hasOwnTheme;

  @override
  Widget build(BuildContext context) {
    const width = 400.0;
    return AlertDialog(
      scrollable: true,
      // To one side, so the lyrics show each colour as it's picked
      alignment: Alignment.centerRight,
      title: const Text('Colour theme'),
      content: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved for this song. To change every song, use Settings → Display.',
              style: TextStyle(
                fontFamily: AppTextStyles.ui,
                fontSize: 13,
                height: 1.45,
                color: AppColors.uiHint,
              ),
            ),
            const SizedBox(height: 16),
            ThemePicker(
              width: width,
              value: _theme,
              onChanged: (theme) {
                setState(() {
                  _theme = theme;
                  _ownTheme = _ownTheme || theme != widget.defaultTheme;
                });
                widget.onChanged(theme);
              },
            ),
          ],
        ),
      ),
      actions: [
        if (_ownTheme && widget.onReset != null)
          TextButton(
            onPressed: () {
              widget.onReset!();
              setState(() {
                _theme = widget.defaultTheme;
                _ownTheme = false;
              });
            },
            child: const Text('Use default colours'),
          ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
