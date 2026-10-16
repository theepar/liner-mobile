import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/lyric.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/lyric_parser.dart';
import '../../../providers/player_provider.dart';

class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key});

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int index, int totalLines) {
    if (!_scrollController.hasClients || index < 0 || index >= totalLines) {
      return;
    }
    if (_lastActiveIndex == index) return;
    _lastActiveIndex = index;

    const itemHeight = 65.0;
    final targetOffset = (index * itemHeight) - 150.0;
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final lyrics = playerState.lyrics;
    final currentMs = playerState.position.inMilliseconds;

    if (playerState.isLoadingLyrics) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: LinerColors.accentPrimary),
            SizedBox(height: 16),
            Text(
              'Syncing lyrics...',
              style: TextStyle(
                color: LinerColors.darkTextSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_off_rounded,
              size: 48,
              color: LinerColors.darkTextTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'No synchronized lyrics available for this track',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LinerColors.darkTextSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final activeIndex = LyricParser.findActiveLineIndex(lyrics, currentMs);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveLine(activeIndex, lyrics.length);
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      itemCount: lyrics.length,
      itemBuilder: (context, index) {
        final line = lyrics[index];
        final isActive = index == activeIndex;
        final isPassed = index < activeIndex;

        return GestureDetector(
          onTap: () {
            ref
                .read(playerStateProvider.notifier)
                .seek(Duration(milliseconds: line.startMs));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: _buildLyricLine(line, isActive, isPassed, currentMs),
          ),
        );
      },
    );
  }

  Widget _buildLyricLine(
    LyricLine line,
    bool isActive,
    bool isPassed,
    int currentMs,
  ) {
    if (line.words.isNotEmpty && isActive) {
      final grouped = LyricParser.groupSyllablesIntoWords(
        line.words,
        line.text,
      );
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: grouped.map((group) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: group.syllables.map((syllable) {
              final progress = LyricParser.getWordProgress(syllable, currentMs);
              final isDone = currentMs >= syllable.endMs;

              return ShaderMask(
                shaderCallback: (bounds) {
                  if (isDone) {
                    return const LinearGradient(
                      colors: [Colors.white, Colors.white],
                    ).createShader(bounds);
                  }
                  return LinearGradient(
                    stops: [0.0, progress, progress, 1.0],
                    colors: [
                      Colors.white,
                      Colors.white,
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.35),
                    ],
                  ).createShader(bounds);
                },
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
            }).toList(),
          );
        }).toList(),
      );
    }

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
        fontSize: isActive ? 26 : 22,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        color: isActive
            ? Colors.white
            : (isPassed
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.4)),
        height: 1.35,
        letterSpacing: -0.3,
      ),
      child: Text(line.text),
    );
  }
}
