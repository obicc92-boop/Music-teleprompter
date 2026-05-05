import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/services/script_parser.dart';

void main() {
  group('ScriptParser', () {
    test('parses plain text with section headers', () {
      const input = '[Intro]\nFirst line\nSecond line\n[Chorus]\nBig moment';
      final script = ScriptParser.parse(input, title: 'Test');

      expect(script.title, 'Test');
      expect(script.sections.length, 2);
      expect(script.sections[0].label, 'INTRO');
      expect(script.sections[1].label, 'CHORUS');
    });

    test('parses section header with bar count', () {
      const input = '[Bridge | 8 bars]\nSome words here';
      final script = ScriptParser.parse(input);
      expect(script.sections.first.lines.first.barCount, 8);
    });

    test('tokenizes words correctly', () {
      const input = 'Hello world from the stage';
      final script = ScriptParser.parse(input);
      expect(script.allLines.first.words, ['Hello', 'world', 'from', 'the', 'stage']);
    });

    test('empty input returns empty script', () {
      final script = ScriptParser.parse('');
      expect(script.isEmpty, true);
    });

    test('LRC format is detected and parsed', () {
      const input = '[00:01.00]First line\n[00:03.50]Second line';
      final script = ScriptParser.parse(input);
      expect(script.allLines.length, 2);
      expect(script.allLines[0].timestamp, closeTo(1.0, 0.01));
      expect(script.allLines[1].timestamp, closeTo(3.5, 0.01));
    });
  });
}
