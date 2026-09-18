import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/services/script_parser.dart';
import 'package:music_teleprompter/widgets/formatted_text_controller.dart';

void main() {
  group('Section headers without square brackets', () {
    List<String?> labels(String lyrics) => [
          for (final l in ScriptParser.parse(lyrics).allLines)
            if (l.isSectionHeader) l.sectionLabel,
        ];

    test('# Chorus, (Chorus) and Chorus: all name a section', () {
      expect(labels('# Intro\nla\n(Chorus)\nla\nBridge:\nla\n[Outro]\nla'),
          ['INTRO', 'CHORUS', 'BRIDGE', 'OUTRO']);
    });

    test('bar counts work in every form', () {
      final script = ScriptParser.parse('# Intro | 4 bars\n(Solo | 8 bars)');
      expect(script.allLines[0].barCount, 4);
      expect(script.allLines[1].barCount, 8);
    });

    test('backing vocals in brackets and lyrics ending in a colon stay lyrics',
        () {
      final lyrics = '(oh yeah)\nListen:\nHere is what I said:\n(Verse 2)';
      expect(labels(lyrics), ['VERSE 2']);
      final script = ScriptParser.parse(lyrics);
      expect(script.allLines[0].text, '(oh yeah)');
      expect(script.allLines[1].text, 'Listen:');
    });

    test('square brackets and # take any name', () {
      expect(labels('[Breakdown]\n# Guitar bit\nla'), ['BREAKDOWN', 'GUITAR BIT']);
    });

    test('arrows still land on the sections', () {
      final script = ScriptParser.parse('Verse 1:\na\nb\nChorus:\nc');
      expect(script.sections.map((s) => s.label), ['VERSE 1', 'CHORUS']);
      expect(script.nextSectionStartLine(0), 3);
    });
  });

  group('Section button', () {
    test('goes in above the caret\'s line, or fills an empty one', () {
      final c = FormattedTextController(text: 'Morning jam\n\nyou still come');
      c.selection = const TextSelection.collapsed(offset: 4); // in "Morning"
      c.insertSection('Verse 1');
      expect(c.text, '[Verse 1]\nMorning jam\n\nyou still come');
      expect(c.selection.start, 10); // at the start of "Morning"

      c.selection = const TextSelection.collapsed(offset: 22); // the empty line
      c.insertSection('Chorus');
      expect(c.text, '[Verse 1]\nMorning jam\n[Chorus]\nyou still come');
      c.dispose();
    });

    test('verses count up', () {
      final c = FormattedTextController(text: '[Verse 1]\na\n[verse 2]\nb\n');
      expect(c.nextVerseName(), 'Verse 3');
      c.dispose();
    });

    test('formatting keeps its place when a section goes in above', () {
      final c = FormattedTextController(text: 'Morning jam');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 7);
      c.style(colorValue: 1);
      c.selection = const TextSelection.collapsed(offset: 3);
      c.insertSection('Verse 1');
      final s = c.formatting.spans.single;
      expect((s.start, s.end), (10, 17));
      c.dispose();
    });
  });
}
