import 'script_line.dart';

class ScriptSection {
  final String label;
  final List<ScriptLine> lines;
  final int? barCount;
  final int startLineIndex;

  const ScriptSection({
    required this.label,
    required this.lines,
    required this.startLineIndex,
    this.barCount,
  });

  int get lineCount => lines.length;

  bool get isEmpty => lines.isEmpty || lines.every((l) => l.isEmpty);

  @override
  String toString() => 'ScriptSection(label: "$label", lines: ${lines.length})';
}
