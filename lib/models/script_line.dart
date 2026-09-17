class ChordSegment {
  final String? chord;
  final String text;

  const ChordSegment({this.chord, required this.text});
}

class ScriptLine {
  final String text;
  final List<String> words;
  final double? timestamp;
  final int? beatIndex;
  final bool isSectionHeader;
  final String? sectionLabel;
  final int? barCount;
  final bool isLoopStart;
  final bool isLoopEnd;
  final List<ChordSegment>? chordSegments;
  /// Per-word start times in seconds from start of audio, used for karaoke highlight.
  final List<double>? wordTimestamps;

  const ScriptLine({
    required this.text,
    required this.words,
    this.timestamp,
    this.beatIndex,
    this.isSectionHeader = false,
    this.sectionLabel,
    this.barCount,
    this.isLoopStart = false,
    this.isLoopEnd = false,
    this.chordSegments,
    this.wordTimestamps,
  });

  ScriptLine copyWith({
    String? text,
    List<String>? words,
    double? timestamp,
    int? beatIndex,
    bool? isSectionHeader,
    String? sectionLabel,
    int? barCount,
    bool? isLoopStart,
    bool? isLoopEnd,
    List<ChordSegment>? chordSegments,
    List<double>? wordTimestamps,
  }) {
    return ScriptLine(
      text: text ?? this.text,
      words: words ?? this.words,
      timestamp: timestamp ?? this.timestamp,
      beatIndex: beatIndex ?? this.beatIndex,
      isSectionHeader: isSectionHeader ?? this.isSectionHeader,
      sectionLabel: sectionLabel ?? this.sectionLabel,
      barCount: barCount ?? this.barCount,
      isLoopStart: isLoopStart ?? this.isLoopStart,
      isLoopEnd: isLoopEnd ?? this.isLoopEnd,
      chordSegments: chordSegments ?? this.chordSegments,
      wordTimestamps: wordTimestamps ?? this.wordTimestamps,
    );
  }

  bool get isEmpty => text.trim().isEmpty && !isSectionHeader;
  bool get hasChords => chordSegments != null && chordSegments!.isNotEmpty;

  @override
  String toString() => 'ScriptLine(text: "$text", isSectionHeader: $isSectionHeader)';
}
