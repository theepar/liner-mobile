import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/models/lyric.dart';
import 'package:liner_mobile/services/lyrics_offset_store.dart';
import 'package:liner_mobile/services/lyrics_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

LyricsCandidate _candidate(
  String provider, {
  String text = 'line',
  LyricsSyncLevel level = LyricsSyncLevel.line,
  num quality = 50,
  String format = 'lrc',
  String? content,
}) => LyricsCandidate(
  provider: provider,
  format: format,
  content: content ?? '[00:01.00]$text',
  syncLevel: level,
  quality: quality,
);

void main() {
  group('LyricsSession', () {
    test('shows the best candidate seen so far', () {
      final session = LyricsSession(durationMs: 10000);

      session.add(_candidate('line', quality: 99));
      expect(session.activeProvider, 'line');

      session.add(_candidate('syllable', level: LyricsSyncLevel.syllable));
      expect(session.activeProvider, 'syllable');
      expect(session.options.map((o) => o.provider), ['syllable', 'line']);
    });

    test('breaks ties between equally synced candidates on quality', () {
      final session = LyricsSession(durationMs: 10000)
        ..add(_candidate('worse', quality: 10, text: 'worse'))
        ..add(_candidate('better', quality: 80, text: 'better'));

      expect(session.activeProvider, 'better');
      expect(session.lines.single.text, 'better');
    });

    test('keeps the provider the user picked when a better one arrives', () {
      final session = LyricsSession(durationMs: 10000)
        ..add(_candidate('first'))
        ..add(_candidate('second', quality: 70));

      expect(session.select('first'), isTrue);
      session.add(_candidate('best', level: LyricsSyncLevel.syllable));

      expect(session.activeProvider, 'first');
      expect(session.options.first.provider, 'best');
    });

    test('rejects an unknown provider selection', () {
      final session = LyricsSession(durationMs: 10000)..add(_candidate('a'));

      expect(session.select('missing'), isFalse);
      expect(session.activeProvider, 'a');
    });

    test('ignores unusable and duplicate candidates', () {
      final session = LyricsSession(durationMs: 10000);

      expect(session.add(_candidate('empty', content: 'no timing')), isFalse);
      expect(session.add(_candidate('a')), isTrue);
      expect(session.add(_candidate('a', text: 'again')), isFalse);
      expect(session.options, hasLength(1));
      expect(session.lines.single.text, 'line');
    });

    test('exposes plain lyrics without lines', () {
      final session = LyricsSession(durationMs: 10000)
        ..add(
          _candidate(
            'plain',
            format: 'plain',
            level: LyricsSyncLevel.plain,
            content: 'just words',
          ),
        );

      expect(session.hasLyrics, isTrue);
      expect(session.lines, isEmpty);
      expect(session.plainText, 'just words');
    });

    test('applies the offset to the shown lines', () {
      final session = LyricsSession(durationMs: 10000, offsetMs: 300)
        ..add(_candidate('a'));

      expect(session.lines.single.startMs, 1300);

      session.setOffset(-400);
      expect(session.lines.single.startMs, 600);
    });

    test('limits the offset to a minute either way', () {
      final session = LyricsSession(durationMs: 10000)..setOffset(500000);
      expect(session.offsetMs, 60000);

      session.setOffset(-500000);
      expect(session.offsetMs, -60000);
      expect(LyricsSession(durationMs: 1, offsetMs: 99999).offsetMs, 60000);
    });
  });

  group('PrefsLyricsOffsetStore', () {
    const store = PrefsLyricsOffsetStore();

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to no offset', () async {
      expect(await store.read('t1'), 0);
    });

    test('remembers an offset per track', () async {
      await store.write('t1', 250);
      await store.write('t2', -100);

      expect(await store.read('t1'), 250);
      expect(await store.read('t2'), -100);
    });

    test('forgets a track once its offset is reset', () async {
      await store.write('t1', 250);
      await store.write('t1', 0);

      expect(await store.read('t1'), 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('liner_lyrics_offsets'), '{}');
    });

    test('drops the oldest entries beyond the limit', () async {
      for (var i = 0; i <= PrefsLyricsOffsetStore.maxEntries; i++) {
        await store.write('t$i', 100);
      }

      expect(await store.read('t0'), 0);
      expect(await store.read('t1'), 100);
      expect(await store.read('t${PrefsLyricsOffsetStore.maxEntries}'), 100);
    });

    test('recovers from corrupted storage', () async {
      SharedPreferences.setMockInitialValues({
        'liner_lyrics_offsets': '{not json',
      });

      expect(await store.read('t1'), 0);
      await store.write('t1', 50);
      expect(await store.read('t1'), 50);
    });
  });
}
