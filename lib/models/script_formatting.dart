import 'script.dart';
import 'script_line.dart';

/// A run of lyrics with its own look: a colour, a size relative to the
/// lyric size, bold. [start] and [end] are character offsets into the song's
/// raw text, kept in step with edits by [ScriptFormatting.edited].
class FormatSpan {
  final int start;
  final int end; // exclusive
  final int? colorValue;
  final double fontSizeScale;
  final bool bold;

  const FormatSpan({
    required this.start,
    required this.end,
    this.colorValue,
    this.fontSizeScale = 1.0,
    this.bold = false,
  });

  int get length => end - start;
  bool get isDefault => colorValue == null && fontSizeScale == 1.0 && !bold;

  bool sameLook(FormatSpan other) =>
      colorValue == other.colorValue &&
      fontSizeScale == other.fontSizeScale &&
      bold == other.bold;

  FormatSpan copyWith({
    int? start,
    int? end,
    int? colorValue,
    bool clearColor = false,
    double? fontSizeScale,
    bool? bold,
  }) =>
      FormatSpan(
        start: start ?? this.start,
        end: end ?? this.end,
        colorValue: clearColor ? null : (colorValue ?? this.colorValue),
        fontSizeScale: fontSizeScale ?? this.fontSizeScale,
        bold: bold ?? this.bold,
      );

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        if (colorValue != null) 'colorValue': colorValue,
        if (fontSizeScale != 1.0) 'fontSizeScale': fontSizeScale,
        if (bold) 'bold': bold,
      };

  factory FormatSpan.fromJson(Map<String, dynamic> j) => FormatSpan(
        start: j['start'] as int,
        end: j['end'] as int,
        colorValue: j['colorValue'] as int?,
        fontSizeScale: (j['fontSizeScale'] as num?)?.toDouble() ?? 1.0,
        bold: j['bold'] as bool? ?? false,
      );
}

/// The look of one word, as earlier versions saved it (by line and word
/// number). Read only to move old files over to [FormatSpan]s.
class WordFormat {
  final int lineIndex;
  final int wordIndex;
  final int? colorValue;
  final double fontSizeScale;
  final bool bold;

  const WordFormat({
    required this.lineIndex,
    required this.wordIndex,
    this.colorValue,
    this.fontSizeScale = 1.0,
    this.bold = false,
  });

  factory WordFormat.fromJson(Map<String, dynamic> j) => WordFormat(
        lineIndex: j['lineIndex'] as int,
        wordIndex: j['wordIndex'] as int,
        colorValue: j['colorValue'] as int?,
        fontSizeScale: (j['fontSizeScale'] as num?)?.toDouble() ?? 1.0,
        bold: j['bold'] as bool? ?? false,
      );
}

/// Every formatted run in a song, sorted and never overlapping.
class ScriptFormatting {
  final List<FormatSpan> spans;

  /// Formats from a file written by an earlier version; [upgraded] turns
  /// them into spans once the lyrics they belong to are known.
  final List<WordFormat> legacy;

  const ScriptFormatting({this.spans = const [], this.legacy = const []});

  static const empty = ScriptFormatting();

  bool get isEmpty => spans.isEmpty && legacy.isEmpty;

  // ── Applying a look ───────────────────────────────────────────────────────

  /// Gives [start]–[end] a look, keeping whatever else those characters had:
  /// colouring bold words keeps them bold.
  ScriptFormatting apply(
    int start,
    int end, {
    int? colorValue,
    bool clearColor = false,
    double? fontSizeScale,
    bool? bold,
  }) {
    if (end <= start) return this;
    FormatSpan restyle(FormatSpan s) => s.copyWith(
          colorValue: colorValue,
          clearColor: clearColor,
          fontSizeScale: fontSizeScale,
          bold: bold,
        );
    final next = <FormatSpan>[];
    var cursor = start; // the first character in the range not yet covered
    for (final s in spans) {
      if (s.end <= start || s.start >= end) {
        next.add(s);
        continue;
      }
      if (s.start < start) next.add(s.copyWith(end: start));
      if (s.start > cursor) {
        next.add(restyle(FormatSpan(start: cursor, end: s.start)));
      }
      final insideStart = s.start < start ? start : s.start;
      final insideEnd = s.end > end ? end : s.end;
      next.add(restyle(s.copyWith(start: insideStart, end: insideEnd)));
      cursor = insideEnd;
      if (s.end > end) next.add(s.copyWith(start: end));
    }
    if (cursor < end) next.add(restyle(FormatSpan(start: cursor, end: end)));
    return ScriptFormatting(spans: _tidy(next), legacy: legacy);
  }

  /// Back to plain lyrics between [start] and [end].
  ScriptFormatting clear(int start, int end) {
    if (end <= start) return this;
    final next = <FormatSpan>[];
    for (final s in spans) {
      if (s.end <= start || s.start >= end) {
        next.add(s);
        continue;
      }
      if (s.start < start) next.add(s.copyWith(end: start));
      if (s.end > end) next.add(s.copyWith(start: end));
    }
    return ScriptFormatting(spans: _tidy(next), legacy: legacy);
  }

  /// The look at one character, or null for plain lyrics.
  FormatSpan? at(int offset) {
    for (final s in spans) {
      if (s.start <= offset && offset < s.end) return s;
    }
    return null;
  }

  /// Sorted, without empty or plain runs, neighbours with one look joined
  static List<FormatSpan> _tidy(List<FormatSpan> input) {
    final sorted = input.where((s) => s.end > s.start && !s.isDefault).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final merged = <FormatSpan>[];
    for (final s in sorted) {
      if (merged.isNotEmpty &&
          merged.last.end == s.start &&
          merged.last.sameLook(s)) {
        merged[merged.length - 1] = merged.last.copyWith(end: s.end);
      } else {
        merged.add(s);
      }
    }
    return merged;
  }

  // ── Following edits ───────────────────────────────────────────────────────

  /// The same formatting after the lyrics changed from [oldText] to
  /// [newText]. Typing inside a coloured phrase extends it; replacing a
  /// whole phrase drops its look.
  ScriptFormatting edited(String oldText, String newText) {
    if (spans.isEmpty || oldText == newText) return this;

    // The edit is the stretch that differs once the common start and end
    // of both texts are peeled off
    var prefix = 0;
    final maxPrefix = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < maxPrefix && oldText[prefix] == newText[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < maxPrefix - prefix &&
        oldText[oldText.length - 1 - suffix] ==
            newText[newText.length - 1 - suffix]) {
      suffix++;
    }
    final removedEnd = oldText.length - suffix; // in the old text
    final inserted = newText.length - suffix - prefix;
    final delta = newText.length - oldText.length;

    final next = <FormatSpan>[];
    for (final s in spans) {
      if (s.end <= prefix) {
        next.add(s);
      } else if (s.start >= removedEnd) {
        next.add(s.copyWith(start: s.start + delta, end: s.end + delta));
      } else if (s.start < prefix && s.end > removedEnd) {
        // The edit sits inside this run, so what was typed takes its look
        next.add(s.copyWith(end: s.end + delta));
      } else if (s.start < prefix) {
        // The run's tail was edited away
        next.add(s.copyWith(end: prefix));
      } else if (s.end > removedEnd) {
        // The run's head was edited away; what's left slides along
        next.add(s.copyWith(start: prefix + inserted, end: s.end + delta));
      }
      // Otherwise the whole run was replaced
    }
    return ScriptFormatting(spans: _tidy(next), legacy: legacy);
  }

  // ── Reading a line's runs ─────────────────────────────────────────────────

  /// The runs touching [start]–[end], clipped and moved so that offsets
  /// count from [start]: what a single line's text needs.
  List<FormatSpan> forRange(int start, int end) {
    if (spans.isEmpty || end <= start) return const [];
    return [
      for (final s in spans)
        if (s.end > start && s.start < end)
          s.copyWith(
            start: (s.start < start ? start : s.start) - start,
            end: (s.end > end ? end : s.end) - start,
          ),
    ];
  }

  /// The runs on [line], offsets counting from its first character.
  List<FormatSpan> forLine(ScriptLine line) {
    final start = line.rawStart;
    if (start == null || spans.isEmpty) return const [];
    return forRange(start, start + line.text.length);
  }

  /// Old per-word formats become spans over the words they named, so a
  /// song formatted with an earlier version keeps its look.
  ScriptFormatting upgraded(Script script) {
    if (legacy.isEmpty) return this;
    var result = ScriptFormatting(spans: spans);
    for (final w in legacy) {
      if (w.lineIndex < 0 || w.lineIndex >= script.allLines.length) continue;
      final line = script.allLines[w.lineIndex];
      final start = line.rawStart;
      if (start == null) continue;
      final words = RegExp(r'\S+').allMatches(line.text).toList();
      if (w.wordIndex < 0 || w.wordIndex >= words.length) continue;
      final m = words[w.wordIndex];
      result = result.apply(
        start + m.start,
        start + m.end,
        colorValue: w.colorValue,
        fontSizeScale: w.fontSizeScale,
        bold: w.bold,
      );
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'spans': spans.map((s) => s.toJson()).toList(),
      };

  factory ScriptFormatting.fromJson(Map<String, dynamic> j) => ScriptFormatting(
        spans: _tidy([
          for (final s in j['spans'] as List<dynamic>? ?? const [])
            FormatSpan.fromJson(s as Map<String, dynamic>),
        ]),
        legacy: [
          for (final e in j['entries'] as List<dynamic>? ?? const [])
            WordFormat.fromJson(e as Map<String, dynamic>),
        ],
      );
}
