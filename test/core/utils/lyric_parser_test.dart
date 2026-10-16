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

    test('stays on the previous line during a gap between lines', () {
      const spaced = [
        LyricLine(startMs: 1000, endMs: 2000, text: 'a'),
        LyricLine(startMs: 8000, endMs: 9000, text: 'b'),
      ];

      expect(LyricParser.findActiveLineIndex(spaced, 5000), 0);
      expect(LyricParser.findActiveLineIndex(spaced, 8000), 1);
      expect(LyricParser.findActiveLineIndex(spaced, 20000), 1);
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

  group('LyricParser.parseTtml', () {
    const ttml = '''
<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
  <body><div>
    <p begin="00:01.000" end="00:03.500"><span begin="00:01.000" end="00:01.500">Hel</span><span begin="00:01.500" end="00:02.000">lo</span> <span begin="00:02.200" end="00:03.500">world</span><span ttm:role="x-translation">Hola</span></p>
    <p begin="5.0s" end="7s">Line only</p>
    <p>No timing</p>
  </div></body>
</tt>''';

    test('reads timed syllables and untimed lines', () {
      final lines = LyricParser.parseTtml(ttml);

      expect(lines, hasLength(2));
      expect(lines[0].startMs, 1000);
      expect(lines[0].endMs, 3500);
      expect(lines[0].text, 'Hello world');
      expect(lines[0].words.map((w) => w.text), ['Hel', 'lo ', 'world']);
      expect(lines[0].words.map((w) => w.startMs), [1000, 1500, 2200]);
      expect(lines[1].startMs, 5000);
      expect(lines[1].endMs, 7000);
      expect(lines[1].text, 'Line only');
      expect(lines[1].words, isEmpty);
    });

    test('returns nothing for invalid XML', () {
      expect(LyricParser.parseTtml('<tt><p begin="1s"'), isEmpty);
    });
  });

  group('LyricParser.parseQrc', () {
    test('reads words with absolute timing', () {
      final lines = LyricParser.parseQrc('''
[1000,2000]Hel(1000,400)lo (1400,300)world(1800,1200)
[4000,1500]Second(4000,1500)
''');

      expect(lines, hasLength(2));
      expect(lines[0].text, 'Hello world');
      expect(lines[0].startMs, 1000);
      expect(lines[0].endMs, 3000);
      expect(lines[0].words.map((w) => w.endMs), [1400, 1700, 3000]);
      expect(lines[1].text, 'Second');
    });

    test('unwraps lyrics embedded in an XML attribute', () {
      final lines = LyricParser.parseQrc(
        '<Lyric_1 LyricType="1" LyricContent="[1000,500]Hi(1000,500)&#10;'
        '[2000,500]There(2000,500)"/>',
      );

      expect(lines.map((l) => l.text), ['Hi', 'There']);
    });
  });

  group('LyricParser.parseCandidate', () {
    LyricsCandidate candidate(
      String format,
      String content, {
      LyricsSyncLevel level = LyricsSyncLevel.line,
    }) => LyricsCandidate(
      provider: 'p',
      format: format,
      content: content,
      syncLevel: level,
    );

    test('keeps plain lyrics as static text', () {
      final document = LyricParser.parseCandidate(
        candidate('plain', '  one\ntwo \n', level: LyricsSyncLevel.plain),
      );

      expect(document.isSynced, isFalse);
      expect(document.plainText, 'one\ntwo');
    });

    test('parses each synced format', () {
      expect(
        LyricParser.parseCandidate(
          candidate('lrc', '[00:01.00]a'),
        ).lines.single.text,
        'a',
      );
      expect(
        LyricParser.parseCandidate(
          candidate(
            'ttml',
            '<tt><body><p begin="1s" end="2s">b</p></body></tt>',
          ),
        ).lines.single.text,
        'b',
      );
      expect(
        LyricParser.parseCandidate(
          candidate('qrc', '[1000,500]c(1000,500)'),
        ).lines.single.text,
        'c',
      );
    });

    test('does not invent timing for a synced format without any', () {
      final document = LyricParser.parseCandidate(
        candidate('lrc', 'no timestamps here'),
      );

      expect(document.isEmpty, isTrue);
    });

    test('falls back to text when the source declares no sync', () {
      final document = LyricParser.parseCandidate(
        candidate('lrc', 'no timestamps', level: LyricsSyncLevel.plain),
      );

      expect(document.plainText, 'no timestamps');
    });
  });

  group('LyricParser.shift', () {
    const lines = [
      LyricLine(
        startMs: 1000,
        endMs: 2000,
        text: 'a',
        words: [LyricWord(startMs: 1000, endMs: 1500, text: 'a')],
      ),
    ];

    test('moves lines and words together', () {
      final shifted = LyricParser.shift(lines, 250).single;

      expect(shifted.startMs, 1250);
      expect(shifted.endMs, 2250);
      expect(shifted.words.single.startMs, 1250);
      expect(shifted.words.single.endMs, 1750);
    });

    test('never moves before the start of the song', () {
      final shifted = LyricParser.shift(lines, -5000).single;

      expect(shifted.startMs, 0);
      expect(shifted.words.single.startMs, 0);
    });

    test('returns the same lines when the offset is zero', () {
      expect(identical(LyricParser.shift(lines, 0), lines), isTrue);
    });
  });
}
