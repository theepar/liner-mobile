import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/models/lyric.dart';
import 'package:liner_mobile/core/utils/lyric_parser.dart';

void main() {
  group('LyricParser.parse', () {
    test('parses LRC lines with timestamps', () {
      const lrc = '''
[00:01.50]Hello world
[00:04.20]This is Liner Mobile
''';
      final parsed = LyricParser.parse(lrc, songDurationMs: 10000);

      expect(parsed, hasLength(2));
      expect(parsed[0].text, 'Hello world');
      expect(parsed[0].startMs, 1500);
      expect(parsed[0].endMs, 4200);
      expect(parsed[1].text, 'This is Liner Mobile');
      expect(parsed[1].endMs, 10000);
    });

    test('parses word-level LRC tags', () {
      final parsed = LyricParser.parse('[00:01.00]<00:01.00>Hel<00:01.40>lo');

      expect(parsed.single.text, 'Hello');
      expect(parsed.single.words.map((w) => w.text), ['Hel', 'lo']);
      expect(parsed.single.words.first.endMs, 1400);
    });

    test('parses Richsync JSON with line-relative word offsets', () {
      const richsync = '''
[{"ts": 10.0, "te": 14.0, "l": [
  {"c": "Hel", "o": 0.0},
  {"c": "lo ", "o": 0.5},
  {"c": "world", "o": 1.5}
]}]''';
      final line = LyricParser.parse(richsync).single;

      expect(line.startMs, 10000);
      expect(line.endMs, 14000);
      expect(line.text, 'Hello world');
      expect(line.words.map((w) => w.startMs), [10000, 10500, 11500]);
      expect(line.words.last.endMs, 14000);
    });

    test('returns no lines for text without timing', () {
      expect(
        LyricParser.parse('just some plain lyrics\nwith no timing'),
        isEmpty,
      );
      expect(LyricParser.parse('   '), isEmpty);
      expect(LyricParser.parse('[not json'), isEmpty);
    });
  });

  group('LyricParser.findActiveLineIndex', () {
    final lines = LyricParser.parse('''
[00:01.00]Line 1
[00:05.00]Line 2
[00:10.00]Line 3
''', songDurationMs: 15000);

    test('selects the line containing the position', () {
      expect(LyricParser.findActiveLineIndex(lines, 500), 0);
      expect(LyricParser.findActiveLineIndex(lines, 2000), 0);
      expect(LyricParser.findActiveLineIndex(lines, 6000), 1);
      expect(LyricParser.findActiveLineIndex(lines, 12000), 2);
    });

    test('is -1 when there are no lines', () {
      expect(LyricParser.findActiveLineIndex(const [], 1000), -1);
    });
  });

  group('LyricParser.getWordProgress', () {
    const word = LyricWord(startMs: 1000, endMs: 2000, text: 'x');

    test('clamps before, during and after the word', () {
      expect(LyricParser.getWordProgress(word, 500), 0);
      expect(LyricParser.getWordProgress(word, 1500), 0.5);
      expect(LyricParser.getWordProgress(word, 3000), 1);
    });
  });

  group('LyricParser.groupSyllablesIntoWords', () {
    test('joins syllables that are not separated by whitespace', () {
      const syllables = [
        LyricWord(startMs: 1000, endMs: 1200, text: 'Hel'),
        LyricWord(startMs: 1200, endMs: 1500, text: 'lo '),
        LyricWord(startMs: 1600, endMs: 2000, text: 'World'),
      ];
      final grouped = LyricParser.groupSyllablesIntoWords(
        syllables,
        'Hello World',
      );

      expect(grouped, hasLength(2));
      expect(grouped[0].text, 'Hello ');
      expect(grouped[0].syllables, hasLength(2));
      expect(grouped[0].startMs, 1000);
      expect(grouped[1].text, 'World');
    });

    test('returns nothing for an empty line', () {
      expect(LyricParser.groupSyllablesIntoWords(const [], ''), isEmpty);
    });
  });
}
