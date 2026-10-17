import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/lyric.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/lyric_parser.dart';
import '../../../providers/player_provider.dart';
import 'lyrics_toolbar.dart';

class LyricsView extends ConsumerWidget {
  const LyricsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(
      playerStateProvider.select(
        (s) => (
          lines: s.lyrics,
          plain: s.lyricsPlainText,
          isLoading: s.isLoadingLyrics,
        ),
      ),
    );

    final Widget body;
    if (content.lines.isNotEmpty) {
      body = _SyncedLyrics(lines: content.lines);
    } else if (content.plain?.isNotEmpty ?? false) {
      body = _PlainLyrics(text: content.plain!);
    } else if (content.isLoading) {
      body = const _LyricsMessage(loading: true, text: 'Syncing lyrics...');
    } else {
      body = const _LyricsMessage(
        icon: Icons.mic_off_rounded,
        text: 'No lyrics available for this track',
      );
    }

    return Column(
      children: [
        const LyricsToolbar(),
        Expanded(child: body),
      ],
    );
  }
}

class _LyricsMessage extends StatelessWidget {
  const _LyricsMessage({required this.text, this.icon, this.loading = false});

  final String text;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          const CircularProgressIndicator(color: LinerColors.accentPrimary)
        else if (icon != null)
          Icon(
            icon,
            size: 48,
            color: LinerColors.darkTextTertiary.withValues(alpha: 0.5),
          ),
        const SizedBox(height: 14),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: LinerColors.darkTextSecondary,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

class _PlainLyrics extends StatelessWidget {
  const _PlainLyrics({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 18,
        height: 1.6,
        fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    ),
  );
}

class _SyncedLyrics extends ConsumerStatefulWidget {
  const _SyncedLyrics({required this.lines});

  final List<LyricLine> lines;

  @override
  ConsumerState<_SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends ConsumerState<_SyncedLyrics> {
  final _scrollController = ScrollController();
  final _keys = <GlobalKey>[];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(int index, {required bool animate}) {
    if (index < 0 || index >= _keys.length) return;
    final target = _keys[index].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.3,
      duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.lines;
    while (_keys.length < lines.length) {
      _keys.add(GlobalKey());
    }
    if (_keys.length > lines.length) _keys.length = lines.length;

    final activeIndex = ref.watch(
      playerStateProvider.select(
        (s) => LyricParser.findActiveLineIndex(
          s.lyrics,
          s.position.inMilliseconds,
        ),
      ),
    );

    ref.listen(
      playerStateProvider.select(
        (s) => (
          lines: s.lyrics,
          index: LyricParser.findActiveLineIndex(
            s.lyrics,
            s.position.inMilliseconds,
          ),
        ),
      ),
      (previous, next) {
        final sourceChanged = !identical(previous?.lines, next.lines);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollTo(next.index, animate: !sourceChanged);
        });
      },
    );

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, line) in lines.indexed)
            GestureDetector(
              key: _keys[index],
              behavior: HitTestBehavior.opaque,
              onTap: () => ref
                  .read(playerStateProvider.notifier)
                  .seek(Duration(milliseconds: line.startMs)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: index == activeIndex && line.words.isNotEmpty
                    ? _ActiveWordLine(line: line)
                    : _PlainLine(
                        text: line.text,
                        isActive: index == activeIndex,
                        isPassed: index < activeIndex,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlainLine extends StatelessWidget {
  const _PlainLine({
    required this.text,
    required this.isActive,
    required this.isPassed,
  });

  final String text;
  final bool isActive;
  final bool isPassed;

  @override
  Widget build(BuildContext context) => AnimatedDefaultTextStyle(
    duration: const Duration(milliseconds: 200),
    style: TextStyle(
      fontSize: isActive ? 26 : 22,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
      color: Colors.white.withValues(
        alpha: isActive ? 1 : (isPassed ? 0.3 : 0.4),
      ),
      height: 1.35,
      letterSpacing: -0.3,
    ),
    child: Text(text),
  );
}

class _ActiveWordLine extends ConsumerWidget {
  const _ActiveWordLine({required this.line});

  final LyricLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMs = ref.watch(
      playerStateProvider.select((s) => s.position.inMilliseconds),
    );
    final grouped = LyricParser.groupSyllablesIntoWords(line.words, line.text);

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final group in grouped)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final syllable in group.syllables)
                _Syllable(syllable: syllable, currentMs: currentMs),
            ],
          ),
      ],
    );
  }
}

class _Syllable extends StatelessWidget {
  const _Syllable({required this.syllable, required this.currentMs});

  final LyricWord syllable;
  final int currentMs;

  @override
  Widget build(BuildContext context) {
    final progress = LyricParser.getWordProgress(syllable, currentMs);
    final isDone = currentMs >= syllable.endMs;

    return ShaderMask(
      shaderCallback: (bounds) => isDone
          ? const LinearGradient(
              colors: [Colors.white, Colors.white],
            ).createShader(bounds)
          : LinearGradient(
              stops: [0.0, progress, progress, 1.0],
              colors: [
                Colors.white,
                Colors.white,
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.35),
              ],
            ).createShader(bounds),
      child: Text(
        syllable.text,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.35,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}
