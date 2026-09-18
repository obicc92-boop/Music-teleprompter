import '../models/script.dart';
import '../models/script_line.dart';
import '../models/script_section.dart';

class ScriptParser {
  static final _sectionHeaderRegex = RegExp(
    r'^\[([^\]|]+?)(?:\s*\|\s*(\d+)\s*bars?)?\]$',
    caseSensitive: false,
  );

  // Not every keyboard has square brackets, so "# Chorus", "(Chorus)" and
  // "Chorus:" mark a section too. Lyrics often hold "(oh yeah)" or end in a
  // colon, so those two forms only count when they name a section word.
  static final _hashHeaderRegex = RegExp(
    r'^#+\s*([^|#][^|]*?)\s*(?:\|\s*(\d+)\s*bars?)?$',
    caseSensitive: false,
  );
  static final _parenHeaderRegex = RegExp(
    r'^\(([^)|]+?)(?:\s*\|\s*(\d+)\s*bars?)?\)$',
    caseSensitive: false,
  );
  static final _colonHeaderRegex = RegExp(
    r"^([A-Za-z][A-Za-z0-9'\- ]{0,30}?)\s*(?:\|\s*(\d+)\s*bars?)?\s*:$",
  );
  static final _sectionWords = RegExp(
    r'\b(intro|verse|pre-?chorus|chorus|refrain|hook|bridge|solo|outro|'
    r'interlude|break(?:down)?|instrumental|tag|coda|ending|drop|vamp|'
    r'middle ?8|turnaround)\b',
    caseSensitive: false,
  );

  /// The section a line names, or null for a lyric line.
  static ({String label, int? bars})? sectionHeader(String trimmed) {
    var match = _sectionHeaderRegex.firstMatch(trimmed) ??
        _hashHeaderRegex.firstMatch(trimmed);
    if (match == null) {
      match = _parenHeaderRegex.firstMatch(trimmed) ??
          _colonHeaderRegex.firstMatch(trimmed);
      if (match == null) return null;
      final label = match.group(1)!.trim();
      if (label.split(RegExp(r'\s+')).length > 3 ||
          !_sectionWords.hasMatch(label)) {
        return null;
      }
    }
    return (
      label: match.group(1)!.trim().toUpperCase(),
      bars: match.group(2) != null ? int.tryParse(match.group(2)!) : null,
    );
  }

  static final _lrcTimestampRegex = RegExp(r'^\[(\d+):(\d+\.\d+)\](.*)$');
  // LRC Enhanced: <mm:ss.xx> or <mm:ss.xxx> word-level markers inside a line
  static final _lrcWordTimestampRegex = RegExp(r'<(\d+):(\d+\.\d+)>([^<]*)');


  // Matches ChordPro inline chords: [Am], [G7], [Cmaj7], [D/F#], etc.
  static final _chordTokenRegex = RegExp(
    r'\[([A-G][#b]?(?:(?:maj|min|m|dim|aug|sus|add|M)[0-9]*|[0-9]*)(?:/[A-G][#b]?)?)\]',
  );

  // ChordPro directive: {title: ...}, {sot}, {chorus}, etc.
  static final _directiveRegex = RegExp(r'^\{([^}]+)\}$');

  static Script parse(String rawText, {String title = 'Untitled'}) {
    if (rawText.trim().isEmpty) return Script.empty();

    final isLrc = _detectLrc(rawText);
    final isChordPro = !isLrc && _detectChordPro(rawText);

    final lines = isLrc
        ? _parseLrc(rawText)
        : isChordPro
            ? _parseChordPro(rawText)
            : _parsePlainText(rawText);

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

  static bool _detectChordPro(String text) {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (_chordTokenRegex.hasMatch(trimmed)) return true;
      if (_directiveRegex.hasMatch(trimmed)) return true;
    }
    return false;
  }

  static List<ScriptLine> _parseLrc(String text) {
    final result = <ScriptLine>[];
    for (final rawLine in text.split('\n')) {
      final trimmed = rawLine.trim();
      final match = _lrcTimestampRegex.firstMatch(trimmed);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = double.parse(match.group(2)!);
        final timestamp = minutes * 60.0 + seconds;
        final rest = match.group(3) ?? '';

        // Try LRC Enhanced: <mm:ss.xx>word markers inside the line
        final wordMatches = _lrcWordTimestampRegex.allMatches(rest).toList();
        if (wordMatches.isNotEmpty) {
          final words = <String>[];
          final wordTs = <double>[];
          for (final wm in wordMatches) {
            final wMin = int.parse(wm.group(1)!);
            final wSec = double.parse(wm.group(2)!);
            final word = wm.group(3)?.trim() ?? '';
            if (word.isNotEmpty) {
              words.add(word);
              wordTs.add(wMin * 60.0 + wSec);
            }
          }
          final lineText = words.join(' ');
          result.add(ScriptLine(
            text: lineText,
            words: words,
            timestamp: timestamp,
            wordTimestamps: wordTs,
          ));
        } else {
          // Plain LRC — word timestamps will be distributed evenly in post-pass
          final lineText = rest.trim();
          result.add(ScriptLine(
            text: lineText,
            words: _tokenize(lineText),
            timestamp: timestamp,
          ));
        }
      } else if (trimmed.isNotEmpty) {
        final section = sectionHeader(trimmed);
        if (section != null) {
          result.add(_buildSectionHeader(section));
        }
      }
    }
    _backfillWordTimestamps(result);
    return result;
  }

  /// For plain LRC lines that have a line timestamp but no word timestamps,
  /// distribute words evenly across the line's duration.
  static void _backfillWordTimestamps(List<ScriptLine> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.timestamp == null || line.wordTimestamps != null) continue;
      if (line.words.isEmpty) continue;

      // Find the next line with a timestamp to determine line duration
      double? nextTs;
      for (int j = i + 1; j < lines.length; j++) {
        if (lines[j].timestamp != null) { nextTs = lines[j].timestamp; break; }
      }
      final duration = nextTs != null
          ? (nextTs - line.timestamp!).clamp(0.5, 10.0)
          : 3.0; // fallback 3s per line

      final wordDuration = duration / line.words.length;
      final ts = List.generate(
        line.words.length,
        (j) => line.timestamp! + j * wordDuration,
      );
      lines[i] = line.copyWith(wordTimestamps: ts);
    }
  }

  static List<ScriptLine> _parseChordPro(String text) {
    final result = <ScriptLine>[];
    for (final rawLine in text.split('\n')) {
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        result.add(const ScriptLine(text: '', words: []));
        continue;
      }

      // ChordPro directive {key: value} → treat as section header or skip
      final directiveMatch = _directiveRegex.firstMatch(trimmed);
      if (directiveMatch != null) {
        final directive = directiveMatch.group(1)!.trim().toLowerCase();
        final colonIdx = directive.indexOf(':');
        final key = colonIdx >= 0 ? directive.substring(0, colonIdx).trim() : directive;
        final value = colonIdx >= 0 ? directive.substring(colonIdx + 1).trim() : '';
        switch (key) {
          case 'title':
          case 't':
            // Skip — title comes from the file name
            break;
          case 'chorus':
          case 'start_of_chorus':
          case 'soc':
            result.add(const ScriptLine(
              text: 'CHORUS',
              words: [],
              isSectionHeader: true,
              sectionLabel: 'CHORUS',
            ));
          case 'verse':
          case 'start_of_verse':
          case 'sov':
            result.add(const ScriptLine(
              text: 'VERSE',
              words: [],
              isSectionHeader: true,
              sectionLabel: 'VERSE',
            ));
          case 'bridge':
          case 'start_of_bridge':
          case 'sob':
            result.add(const ScriptLine(
              text: 'BRIDGE',
              words: [],
              isSectionHeader: true,
              sectionLabel: 'BRIDGE',
            ));
          case 'end_of_chorus':
          case 'eoc':
          case 'end_of_verse':
          case 'eov':
          case 'end_of_bridge':
          case 'eob':
          case 'comment':
          case 'c':
            if (value.isNotEmpty) {
              result.add(ScriptLine(
                text: value.toUpperCase(),
                words: [],
                isSectionHeader: true,
                sectionLabel: value.toUpperCase(),
              ));
            }
          default:
            // Unknown directive — skip silently
            break;
        }
        continue;
      }

      // Chord line — any line with inline chord tokens takes priority over section headers
      // (guards against [Am] alone being misread as section header "AM")
      if (_chordTokenRegex.hasMatch(trimmed)) {
        result.add(_parseChordLine(trimmed));
        continue;
      }

      // Plain section header [Verse 1] — only reached when no chord tokens present
      final section = sectionHeader(trimmed);
      if (section != null) {
        result.add(_buildSectionHeader(section));
        continue;
      }

      // Plain lyric line
      result.add(ScriptLine(
        text: trimmed,
        words: _tokenize(trimmed),
      ));
    }
    return result;
  }

  static ScriptLine _parseChordLine(String line) {
    final segments = <ChordSegment>[];
    final matches = _chordTokenRegex.allMatches(line).toList();

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final chord = match.group(1)!;

      // Text between this chord token and the next (or end of line)
      final textStart = match.end;
      final textEnd = i + 1 < matches.length ? matches[i + 1].start : line.length;
      final text = line.substring(textStart, textEnd);

      // Any plain text before the first chord becomes a no-chord prefix segment
      if (i == 0 && match.start > 0) {
        final prefix = line.substring(0, match.start);
        if (prefix.isNotEmpty) {
          segments.add(ChordSegment(chord: null, text: prefix));
        }
      }

      segments.add(ChordSegment(chord: chord, text: text));
    }

    // Build the plain text version by concatenating segment texts
    final plainText = segments.map((s) => s.text).join();

    return ScriptLine(
      text: plainText,
      words: _tokenize(plainText),
      chordSegments: segments,
    );
  }

  static List<ScriptLine> _parsePlainText(String text) {
    final result = <ScriptLine>[];
    var offset = 0; // where the current raw line starts in the text
    for (final rawLine in text.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        result.add(ScriptLine(text: '', words: [], rawStart: offset));
      } else {
        final section = sectionHeader(trimmed);
        if (section != null) {
          result.add(_buildSectionHeader(section)
              .copyWith(rawStart: offset + rawLine.indexOf(trimmed)));
        } else {
          result.add(ScriptLine(
            text: trimmed,
            words: _tokenize(trimmed),
            rawStart: offset + rawLine.indexOf(trimmed),
          ));
        }
      }
      offset += rawLine.length + 1;
    }
    return result;
  }

  static ScriptLine _buildSectionHeader(({String label, int? bars}) section) {
    return ScriptLine(
      text: section.label,
      words: [],
      isSectionHeader: true,
      sectionLabel: section.label,
      barCount: section.bars,
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
