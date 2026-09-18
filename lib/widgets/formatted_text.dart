import 'package:flutter/material.dart';
import '../models/script_formatting.dart';

/// [text] as spans, each run of formatting in its own look on top of [base].
/// [spans] count from the start of [text].
List<InlineSpan> formattedSpans(
  String text,
  List<FormatSpan> spans,
  TextStyle base,
) {
  if (spans.isEmpty) return [TextSpan(text: text, style: base)];
  final result = <InlineSpan>[];
  var cursor = 0;
  for (final s in spans) {
    final start = s.start.clamp(0, text.length);
    final end = s.end.clamp(0, text.length);
    if (end <= start) continue;
    if (start > cursor) {
      result.add(TextSpan(text: text.substring(cursor, start), style: base));
    }
    result.add(TextSpan(
      text: text.substring(start, end),
      style: styleFor(s, base),
    ));
    cursor = end;
  }
  if (cursor < text.length) {
    result.add(TextSpan(text: text.substring(cursor), style: base));
  }
  return result;
}

/// [base] with one run's colour, size and weight. A dimmed line (the lines
/// around the current one) dims its coloured words just as much.
TextStyle styleFor(FormatSpan span, TextStyle base) => base.copyWith(
      color: span.colorValue != null
          ? Color(span.colorValue!)
              .withValues(alpha: base.color?.a ?? 1.0)
          : base.color,
      fontSize:
          base.fontSize != null ? base.fontSize! * span.fontSizeScale : null,
      fontWeight: span.bold ? FontWeight.w900 : base.fontWeight,
    );

/// The size steps A− and A+ move through, as a share of the lyric size.
const fontSizeSteps = [0.8, 0.9, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0];

/// The next step up or down from [scale]; stays put at either end.
double steppedFontSize(double scale, int direction) {
  var index = 0;
  var best = double.infinity;
  for (var i = 0; i < fontSizeSteps.length; i++) {
    final d = (fontSizeSteps[i] - scale).abs();
    if (d < best) {
      best = d;
      index = i;
    }
  }
  return fontSizeSteps[(index + direction).clamp(0, fontSizeSteps.length - 1)];
}
