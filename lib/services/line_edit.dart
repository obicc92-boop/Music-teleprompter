import '../models/script.dart';
import '../models/script_formatting.dart';

/// What changes when one line of a song is rewritten on the stage screen.
class LineEdit {
  LineEdit._();

  /// [formatting] after [start]–[end] of [oldText] became [newText], which
  /// carries its own [look] (offsets from the start of [newText]). The old
  /// look on that stretch goes, everything after it slides along, and the
  /// new look is laid over the new text.
  static ScriptFormatting replaceRange(
    ScriptFormatting formatting,
    String oldText,
    int start,
    int end,
    String newText,
    ScriptFormatting look,
  ) {
    final newRaw = oldText.replaceRange(start, end, newText);
    var result = formatting.clear(start, end).edited(oldText, newRaw);
    for (final s in look.spans) {
      result = result.apply(
        start + s.start,
        start + s.end,
        colorValue: s.colorValue,
        fontSizeScale: s.fontSizeScale,
        bold: s.bold,
      );
    }
    return result;
  }

  /// Times for the lyric lines of [newScript] after line [editedLine] was
  /// rewritten, given the [oldTimeline] (line, seconds) of the song before.
  /// Lines before the edit keep their time, lines after it move by [added]
  /// (how many lines the edit added, negative when it removed some). The
  /// first lyric line the edit left in place keeps the edited line's time,
  /// even behind a new blank line; other lines the edit created take a time
  /// between their neighbours.
  static Map<int, double> retime(
    Script newScript,
    int editedLine,
    int added,
    List<(int, double)> oldTimeline,
  ) {
    final times = <int, double>{for (final (l, t) in oldTimeline) l: t};
    final result = <int, double>{};
    bool lyric(int i) {
      final l = newScript.allLines[i];
      return !l.isSectionHeader && !l.isEmpty;
    }

    var editedKept = false; // the edited line's time, given out once
    for (var i = 0; i < newScript.totalLines; i++) {
      if (!lyric(i)) continue;
      int? was;
      if (i < editedLine) {
        was = i;
      } else if (i <= editedLine + added && !editedKept) {
        was = editedLine;
        editedKept = true;
      } else if (i > editedLine + added) {
        was = i - added;
      }
      if (was != null && times.containsKey(was)) result[i] = times[was]!;
    }

    final timed = result.keys.toList()..sort();
    for (var i = editedLine + 1; i <= editedLine + added; i++) {
      if (i >= newScript.totalLines || !lyric(i) || result.containsKey(i)) {
        continue;
      }
      final before = timed.lastWhere((k) => k < i, orElse: () => -1);
      if (before < 0) continue;
      final after = timed.firstWhere((k) => k > i, orElse: () => -1);
      final t0 = result[before]!;
      // Past the last timed line, keep a steady three seconds a line
      final t1 = after < 0 ? t0 + 3.0 * (i - before) : result[after]!;
      final span = (after < 0 ? i : after) - before;
      result[i] = t0 + (t1 - t0) * (i - before) / span;
    }
    return result;
  }
}
