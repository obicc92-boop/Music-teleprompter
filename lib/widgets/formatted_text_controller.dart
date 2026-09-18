import 'package:flutter/material.dart';
import '../models/script_formatting.dart';
import 'formatted_text.dart';

/// A text controller whose lyrics show their colours, sizes and bold as
/// they're typed, and whose formatting moves with every edit.
class FormattedTextController extends TextEditingController {
  ScriptFormatting _formatting;

  FormattedTextController({
    super.text,
    ScriptFormatting formatting = ScriptFormatting.empty,
  }) : _formatting = formatting;

  ScriptFormatting get formatting => _formatting;

  set formatting(ScriptFormatting value) {
    _formatting = value;
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    if (newValue.text != text) {
      _formatting = _formatting.edited(text, newValue.text);
    }
    super.value = newValue;
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  /// Puts "[name]" on its own line where the caret is: on an empty line it
  /// fills that line, otherwise it goes in above the caret's line. The caret
  /// ends up after it, ready for the next line.
  void insertSection(String name) {
    final caret = selection.isValid ? selection.start : text.length;
    final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
    var lineEnd = text.indexOf('\n', caret);
    if (lineEnd < 0) lineEnd = text.length;
    final header = '[$name]';
    final lineIsEmpty = text.substring(lineStart, lineEnd).trim().isEmpty;
    final insert = lineIsEmpty ? header : '$header\n';
    final before = text.substring(0, lineStart);
    final after = text.substring(lineIsEmpty ? lineEnd : lineStart);
    value = TextEditingValue(
      text: '$before$insert$after',
      selection: TextSelection.collapsed(offset: lineStart + insert.length),
    );
  }

  /// "Verse 3" when the lyrics already have two verses.
  String nextVerseName() {
    final numbers = RegExp(r'\[\s*verse\s*(\d+)', caseSensitive: false)
        .allMatches(text)
        .map((m) => int.tryParse(m.group(1)!) ?? 0);
    var highest = 0;
    for (final n in numbers) {
      if (n > highest) highest = n;
    }
    return 'Verse ${highest + 1}';
  }

  // ── The words being styled ────────────────────────────────────────────────

  /// The whole words the selection touches, or the word under the caret;
  /// null when there's nothing to style.
  TextRange? get targetWords {
    final sel = selection;
    if (!sel.isValid) return null;
    var start = sel.start;
    var end = sel.end;
    // Whitespace at either edge of a drag isn't part of the words
    while (start < end && _isSpace(text[start])) {
      start++;
    }
    while (end > start && _isSpace(text[end - 1])) {
      end--;
    }
    if (start == end) {
      // A caret: the word around it
      if (start < text.length && !_isSpace(text[start])) {
        end = start + 1;
      } else if (start > 0 && !_isSpace(text[start - 1])) {
        start--;
        end = start + 1;
      } else {
        return null;
      }
    }
    while (start > 0 && !_isSpace(text[start - 1])) {
      start--;
    }
    while (end < text.length && !_isSpace(text[end])) {
      end++;
    }
    return TextRange(start: start, end: end);
  }

  static bool _isSpace(String c) => c.trim().isEmpty;

  /// The look at the start of the target words, for the toolbar to show.
  FormatSpan? get targetLook {
    final range = targetWords;
    return range == null ? null : _formatting.at(range.start);
  }

  /// Gives the target words a look; other looks they had are kept.
  void style({
    int? colorValue,
    bool clearColor = false,
    double? fontSizeScale,
    bool? bold,
  }) {
    final range = targetWords;
    if (range == null) return;
    formatting = _formatting.apply(
      range.start,
      range.end,
      colorValue: colorValue,
      clearColor: clearColor,
      fontSizeScale: fontSizeScale,
      bold: bold,
    );
    _keepSelection(range);
  }

  void toggleBold() => style(bold: !(targetLook?.bold ?? false));

  void stepFontSize(int direction) => style(
      fontSizeScale:
          steppedFontSize(targetLook?.fontSizeScale ?? 1.0, direction));

  /// The target words back to plain lyrics.
  void clearStyle() {
    final range = targetWords;
    if (range == null) return;
    formatting = _formatting.clear(range.start, range.end);
    _keepSelection(range);
  }

  // Selecting the styled words shows what changed and lets the next button
  // act on the same words
  void _keepSelection(TextRange range) {
    selection = TextSelection(baseOffset: range.start, extentOffset: range.end);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    return TextSpan(
      style: base,
      children: formattedSpans(text, _formatting.spans, base),
    );
  }
}
