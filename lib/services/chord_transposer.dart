import '../models/script.dart';
import '../models/script_line.dart';

class ChordTransposer {
  static const _sharps = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  static const _flats  = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'];

  // Black-key semitone indices — these need a sharp or flat spelling
  static const _blackKeys = {1, 3, 6, 8, 10};

  /// Returns a new [Script] with all chord segments transposed by [semitones].
  static Script transposeScript(Script script, int semitones) {
    if (semitones == 0) return script;
    final s = ((semitones % 12) + 12) % 12;
    final transposedLines = script.allLines.map((line) {
      if (!line.hasChords) return line;
      final newSegs = line.chordSegments!.map((seg) {
        if (seg.chord == null) return seg;
        return ChordSegment(chord: _transposeChord(seg.chord!, s), text: seg.text);
      }).toList();
      return line.copyWith(chordSegments: newSegs);
    }).toList();
    return script.copyWith(allLines: transposedLines);
  }

  static String _transposeChord(String chord, int semitones) {
    final slashIdx = chord.lastIndexOf('/');
    final mainPart = slashIdx >= 0 ? chord.substring(0, slashIdx) : chord;
    final bassPart = slashIdx >= 0 ? chord.substring(slashIdx + 1) : null;

    final root = _parseRoot(mainPart);
    if (root == null) return chord;

    final quality = mainPart.substring(root.length);
    final useFlats = root.length == 2 && root[1] == 'b';
    final newRoot = _shiftRoot(root, semitones, useFlats);
    final newBass = bassPart != null ? _shiftRoot(bassPart, semitones, useFlats) : null;

    return newBass != null ? '$newRoot$quality/$newBass' : '$newRoot$quality';
  }

  static String? _parseRoot(String chord) {
    if (chord.isEmpty) return null;
    if (!RegExp(r'[A-G]').hasMatch(chord[0])) return null;
    if (chord.length > 1 && (chord[1] == '#' || chord[1] == 'b')) {
      return chord.substring(0, 2);
    }
    return chord.substring(0, 1);
  }

  static String _shiftRoot(String root, int semitones, bool preferFlats) {
    int idx = _sharps.indexOf(root);
    if (idx < 0) idx = _flats.indexOf(root);
    if (idx < 0) return root;

    final newIdx = (idx + semitones) % 12;
    if (!_blackKeys.contains(newIdx)) return _sharps[newIdx];
    return preferFlats ? _flats[newIdx] : _sharps[newIdx];
  }

  /// Returns a display label for the current transpose offset, e.g. "+2", "0", "-3".
  static String offsetLabel(int semitones) {
    final s = ((semitones % 12) + 12) % 12;
    if (s == 0) return '0';
    // Show as signed offset in range -6..+6
    final signed = s > 6 ? s - 12 : s;
    return signed > 0 ? '+$signed' : '$signed';
  }
}
