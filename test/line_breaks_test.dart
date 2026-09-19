import 'package:flutter_test/flutter_test.dart';
import 'package:music_teleprompter/services/script_parser.dart';

/// Lyrics from other apps break lines in other ways: Word's Shift+Enter
/// is a vertical tab, old Mac files use a carriage return, and some apps
/// paste the Unicode line separator. A verse joined by those must still
/// come out as separate lines.
void main() {
  test('a verse joined by soft returns becomes separate lines', () {
    const verse = "Old greedy men in power's grip,"
        'Promises sink as lies let slip'
        'They drain the well, the people fall';
    final script = ScriptParser.parse('[Verse 1]\n$verse\n\nthe power in wrong hands');
    expect(script.allLines.map((l) => l.text), [
      'VERSE 1',
      "Old greedy men in power's grip,",
      'Promises sink as lies let slip',
      'They drain the well, the people fall',
      '',
      'the power in wrong hands',
    ]);
  });

  test('every odd line break counts, and offsets still line up', () {
    const text = 'one\rtwo three fourfivesix\r\nseven';
    final script = ScriptParser.parse(text);
    expect(script.allLines.map((l) => l.text),
        ['one', 'two', 'three', 'four', 'five', 'six', 'seven']);
    // One character for one, so nothing measured in offsets moves
    expect(script.rawText.length, text.length);
    for (final line in script.allLines) {
      expect(
        script.rawText.substring(line.rawStart!, line.rawStart! + line.text.length),
        line.text,
      );
    }
  });

  test('Windows line endings were already fine', () {
    final script = ScriptParser.parse('one\r\ntwo\r\n');
    expect(script.allLines.map((l) => l.text), ['one', 'two', '']);
  });
}
