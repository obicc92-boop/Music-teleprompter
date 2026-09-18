import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/song_theme.dart';
import '../utils/constants.dart';

/// Colour, strength and brightness sliders plus a hex code: one colour,
/// edited in place. Shared by the colour theme picker and the lyrics editor.
class ColourSliders extends StatefulWidget {
  final HSVColor value;
  final ValueChanged<HSVColor> onChanged;

  /// Owners that keep the hex field across rebuilds can pass their own.
  final TextEditingController? hexController;
  final FocusNode? hexFocus;

  const ColourSliders({
    super.key,
    required this.value,
    required this.onChanged,
    this.hexController,
    this.hexFocus,
  });

  @override
  State<ColourSliders> createState() => _ColourSlidersState();
}

class _ColourSlidersState extends State<ColourSliders> {
  late final TextEditingController _hex =
      widget.hexController ?? TextEditingController();
  late final FocusNode _hexFocus = widget.hexFocus ?? FocusNode();

  @override
  void initState() {
    super.initState();
    _showHex();
  }

  @override
  void didUpdateWidget(ColourSliders oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) _showHex();
  }

  @override
  void dispose() {
    if (widget.hexController == null) _hex.dispose();
    if (widget.hexFocus == null) _hexFocus.dispose();
    super.dispose();
  }

  void _showHex() {
    if (!_hexFocus.hasFocus) _hex.text = SongTheme.hex(widget.value.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final hsv = widget.value;
    final colour = hsv.toColor();
    // Strength is easier to judge on a colour that isn't nearly black
    final visible = hsv.withValue(math.max(hsv.value, 0.45));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          'Colour',
          GradientSlider(
            colours: [
              for (var h = 0; h <= 360; h += 60)
                HSVColor.fromAHSV(1, h % 360.0, 1, 1).toColor(),
            ],
            value: hsv.hue / 360,
            thumb: HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
            onChanged: (v) =>
                widget.onChanged(hsv.withHue(math.min(v * 360, 359.9))),
          ),
        ),
        _row(
          'Strength',
          GradientSlider(
            colours: [
              visible.withSaturation(0).toColor(),
              visible.withSaturation(1).toColor(),
            ],
            value: hsv.saturation,
            thumb: colour,
            onChanged: (v) => widget.onChanged(hsv.withSaturation(v)),
          ),
        ),
        // Squared, so the dark shades a background needs get most of the
        // slider instead of its first sliver
        _row(
          'Brightness',
          GradientSlider(
            colours: [
              for (final p in const [0.0, 0.25, 0.5, 0.75, 1.0])
                hsv.withValue(p * p).toColor(),
            ],
            value: math.sqrt(hsv.value),
            thumb: colour,
            onChanged: (v) => widget.onChanged(hsv.withValue(v * v)),
          ),
        ),
        const SizedBox(height: 6),
        _row('Hex code', Align(alignment: Alignment.centerLeft, child: _hexField())),
      ],
    );
  }

  Widget _row(String label, Widget control) {
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
                if (colour != null) widget.onChanged(HSVColor.fromColor(colour));
              },
              onSubmitted: (_) => _hexFocus.unfocus(),
            ),
          ),
        ],
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

