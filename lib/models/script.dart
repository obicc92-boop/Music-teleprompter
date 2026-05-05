import 'script_line.dart';
import 'script_section.dart';

class Script {
  final String title;
  final List<ScriptSection> sections;
  final List<ScriptLine> allLines;
  final String rawText;

  const Script({
    required this.title,
    required this.sections,
    required this.allLines,
    required this.rawText,
  });

  static Script empty() => const Script(
    title: 'Untitled',
    sections: [],
    allLines: [],
    rawText: '',
  );

  bool get isEmpty => allLines.isEmpty;

  int get totalLines => allLines.length;

  ScriptLine? lineAt(int index) {
    if (index < 0 || index >= allLines.length) return null;
    return allLines[index];
  }

  int sectionIndexForLine(int lineIndex) {
    for (int i = sections.length - 1; i >= 0; i--) {
      if (sections[i].startLineIndex <= lineIndex) return i;
    }
    return 0;
  }

  int nextSectionStartLine(int currentLineIndex) {
    final sectionIdx = sectionIndexForLine(currentLineIndex);
    if (sectionIdx + 1 < sections.length) {
      return sections[sectionIdx + 1].startLineIndex;
    }
    return allLines.length - 1;
  }

  int prevSectionStartLine(int currentLineIndex) {
    final sectionIdx = sectionIndexForLine(currentLineIndex);
    if (sectionIdx > 0) {
      return sections[sectionIdx - 1].startLineIndex;
    }
    return 0;
  }

  Script copyWith({
    String? title,
    List<ScriptSection>? sections,
    List<ScriptLine>? allLines,
    String? rawText,
  }) {
    return Script(
      title: title ?? this.title,
      sections: sections ?? this.sections,
      allLines: allLines ?? this.allLines,
      rawText: rawText ?? this.rawText,
    );
  }
}
