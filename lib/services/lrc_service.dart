import 'dart:io';
import '../models/script.dart';

class LrcLine {
  final Duration timestamp;
  final String text;
  const LrcLine({required this.timestamp, required this.text});
}

class LrcService {
  static List<LrcLine> parseFile(String path) {
    final content = File(path).readAsStringSync();
    return parse(content);
  }

  static List<LrcLine> parse(String content) {
    final lines = <LrcLine>[];
    // Skip metadata tags e.g. [ar:], [ti:], [al:], [by:], [offset:]
    final metaRe = RegExp(r'^\[(?:ar|ti|al|by|offset|length|re|ve):');
    // Timestamp: [mm:ss.xx] or [mm:ss.xxx] or [mm:ss]
    final tsRe = RegExp(r'\[(\d+):(\d{2})(?:\.(\d{2,3}))?\]');

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (metaRe.hasMatch(line)) continue;

      final match = tsRe.firstMatch(line);
      if (match == null) continue;

      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final subStr = match.group(3);
      int ms = 0;
      if (subStr != null) {
        ms = subStr.length == 2
            ? int.parse(subStr) * 10  // centiseconds → ms
            : int.parse(subStr);      // already ms
      }

      final text = line.substring(match.end).trim();
      final ts = Duration(minutes: min, seconds: sec, milliseconds: ms);
      lines.add(LrcLine(timestamp: ts, text: text));
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  /// Maps LRC lines sequentially to lyric line indices in the script.
  /// Section headers and blank lines in the script are skipped.
  static List<(int, Duration)> matchToScript(
      List<LrcLine> lrcLines, Script script) {
    final lyricIndices = <int>[];
    for (int i = 0; i < script.allLines.length; i++) {
      final l = script.allLines[i];
      if (!l.isSectionHeader && !l.isEmpty) lyricIndices.add(i);
    }

    final lrcLyrics = lrcLines.where((l) => l.text.isNotEmpty).toList();
    final count = lrcLyrics.length < lyricIndices.length
        ? lrcLyrics.length
        : lyricIndices.length;

    return [
      for (int i = 0; i < count; i++) (lyricIndices[i], lrcLyrics[i].timestamp)
    ];
  }

  /// Returns the script line index that should be active for [position].
  static int? activeLineIndex(
      List<(int, Duration)> timestamps, Duration position) {
    if (timestamps.isEmpty) return null;
    int result = timestamps.first.$1;
    for (final (idx, ts) in timestamps) {
      if (position >= ts) {
        result = idx;
      } else {
        break;
      }
    }
    return result;
  }
}
