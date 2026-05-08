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

  bool get isDefault => colorValue == null && fontSizeScale == 1.0 && !bold;

  WordFormat copyWith({
    int? colorValue,
    bool clearColor = false,
    double? fontSizeScale,
    bool? bold,
  }) =>
      WordFormat(
        lineIndex: lineIndex,
        wordIndex: wordIndex,
        colorValue: clearColor ? null : (colorValue ?? this.colorValue),
        fontSizeScale: fontSizeScale ?? this.fontSizeScale,
        bold: bold ?? this.bold,
      );

  Map<String, dynamic> toJson() => {
        'lineIndex': lineIndex,
        'wordIndex': wordIndex,
        if (colorValue != null) 'colorValue': colorValue,
        'fontSizeScale': fontSizeScale,
        'bold': bold,
      };

  factory WordFormat.fromJson(Map<String, dynamic> j) => WordFormat(
        lineIndex: j['lineIndex'] as int,
        wordIndex: j['wordIndex'] as int,
        colorValue: j['colorValue'] as int?,
        fontSizeScale: (j['fontSizeScale'] as num?)?.toDouble() ?? 1.0,
        bold: j['bold'] as bool? ?? false,
      );
}

class ScriptFormatting {
  final List<WordFormat> entries;

  const ScriptFormatting({this.entries = const []});

  static const empty = ScriptFormatting();

  bool get isEmpty => entries.isEmpty;

  WordFormat? formatFor(int lineIndex, int wordIndex) {
    for (final e in entries) {
      if (e.lineIndex == lineIndex && e.wordIndex == wordIndex) return e;
    }
    return null;
  }

  bool hasFormatsForLine(int lineIndex) =>
      entries.any((e) => e.lineIndex == lineIndex);

  ScriptFormatting withUpdate(WordFormat updated) {
    final next = entries
        .where((e) =>
            !(e.lineIndex == updated.lineIndex &&
              e.wordIndex == updated.wordIndex))
        .toList();
    if (!updated.isDefault) next.add(updated);
    return ScriptFormatting(entries: next);
  }

  ScriptFormatting clearWord(int lineIndex, int wordIndex) => ScriptFormatting(
        entries: entries
            .where((e) =>
                !(e.lineIndex == lineIndex && e.wordIndex == wordIndex))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory ScriptFormatting.fromJson(Map<String, dynamic> j) => ScriptFormatting(
        entries: (j['entries'] as List<dynamic>? ?? [])
            .map((e) => WordFormat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
