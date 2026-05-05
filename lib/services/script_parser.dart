import '../models/script.dart';
import '../models/script_line.dart';
import '../models/script_section.dart';

class ScriptParser {
  static final _sectionHeaderRegex = RegExp(
    r'^\[([^\]|]+?)(?:\s*\|\s*(\d+)\s*bars?)?\]$',
    caseSensitive: false,
  );

  static final _lrcTimestampRegex = RegExp(r'^\[(\d+):(\d+\.\d+)\](.*)$');

  static Script parse(String rawText, {String title = 'Untitled'}) {
    if (rawText.trim().isEmpty) return Script.empty();

    final isLrc = _detectLrc(rawText);
    final lines = isLrc ? _parseLrc(rawText) : _parsePlainText(rawText);

    final sections = _buildSections(lines);

    return Script(
      title: title,
      sections: sections,
      allLines: lines,
      rawText: rawText,
    );
  }

  static bool _detectLrc(String text) {
    return _lrcTimestampRegex.hasMatch(text.split('\n').first.trim());
  }

  static List<ScriptLine> _parseLrc(String text) {
    final result = <ScriptLine>[];
    for (final rawLine in text.split('\n')) {
      final trimmed = rawLine.trim();
      final match = _lrcTimestampRegex.firstMatch(trimmed);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = double.parse(match.group(2)!);
        final lineText = match.group(3)?.trim() ?? '';
        final timestamp = minutes * 60.0 + seconds;
        result.add(ScriptLine(
          text: lineText,
          words: _tokenize(lineText),
          timestamp: timestamp,
        ));
      } else if (trimmed.isNotEmpty) {
        final sectionMatch = _sectionHeaderRegex.firstMatch(trimmed);
        if (sectionMatch != null) {
          result.add(_buildSectionHeader(sectionMatch));
        }
      }
    }
    return result;
  }

  static List<ScriptLine> _parsePlainText(String text) {
    final result = <ScriptLine>[];
    for (final rawLine in text.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        result.add(const ScriptLine(text: '', words: []));
        continue;
      }
      final sectionMatch = _sectionHeaderRegex.firstMatch(trimmed);
      if (sectionMatch != null) {
        result.add(_buildSectionHeader(sectionMatch));
      } else {
        result.add(ScriptLine(
          text: trimmed,
          words: _tokenize(trimmed),
        ));
      }
    }
    return result;
  }

  static ScriptLine _buildSectionHeader(RegExpMatch match) {
    final label = match.group(1)!.trim().toUpperCase();
    final bars = match.group(2) != null ? int.tryParse(match.group(2)!) : null;
    return ScriptLine(
      text: label,
      words: [],
      isSectionHeader: true,
      sectionLabel: label,
      barCount: bars,
    );
  }

  static List<String> _tokenize(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  static List<ScriptSection> _buildSections(List<ScriptLine> lines) {
    if (lines.isEmpty) return [];

    final sections = <ScriptSection>[];
    String currentLabel = 'INTRO';
    int currentStart = 0;
    final currentLines = <ScriptLine>[];

    void flushSection() {
      if (currentLines.isNotEmpty) {
        sections.add(ScriptSection(
          label: currentLabel,
          lines: List.unmodifiable(currentLines),
          startLineIndex: currentStart,
        ));
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isSectionHeader) {
        flushSection();
        currentLabel = line.sectionLabel ?? 'SECTION';
        currentStart = i;
        currentLines.clear();
        currentLines.add(line);
      } else {
        currentLines.add(line);
      }
    }

    flushSection();

    if (sections.isEmpty) {
      sections.add(ScriptSection(
        label: 'SONG',
        lines: List.unmodifiable(lines),
        startLineIndex: 0,
      ));
    }

    return sections;
  }
}
