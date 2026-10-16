import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/utils/lyric_parser.dart';

void main() {
  group('LyricParser Tests', () {
    test('Parses LRC format correctly', () {
      const lrc = '''
[00:01.50]Hello world
[00:04.20]This is Liner Mobile
''';
      final parsed = LyricParser.parse(lrc, songDurationMs: 10000);
      expect(parsed.length, 2);
      expect(parsed[0].text, 'Hello world');
      expect(parsed[0].startMs, 1500);
      expect(parsed[1].text, 'This is Liner Mobile');
      expect(parsed[1].startMs, 4200);
    });

    test('Finds active line index accurately', () {
      const lrc = '''
[00:01.00]Line 1
[00:05.00]Line 2
[00:10.00]Line 3
''';
      final parsed = LyricParser.parse(lrc, songDurationMs: 15000);
      expect(LyricParser.findActiveLineIndex(parsed, 500), 0);
      expect(LyricParser.findActiveLineIndex(parsed, 2000), 0);
      expect(LyricParser.findActiveLineIndex(parsed, 6000), 1);
      expect(LyricParser.findActiveLineIndex(parsed, 12000), 2);
    });
  });
}
