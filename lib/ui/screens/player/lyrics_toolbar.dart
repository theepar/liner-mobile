import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/player_provider.dart';

class LyricsToolbar extends ConsumerWidget {
  const LyricsToolbar({super.key});

  static const _step = 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(
      playerStateProvider.select(
        (s) => (
          options: s.lyricsOptions,
          active: s.activeLyricsProvider,
          offset: s.lyricsOffsetMs,
          isSynced: s.lyrics.isNotEmpty,
        ),
      ),
    );
    if (view.options.isEmpty) return const SizedBox.shrink();

    final notifier = ref.read(playerStateProvider.notifier);
    final options = view.options;
    final index = options.indexWhere((o) => o.provider == view.active);
    final current = index < 0 ? 0 : index;
    final hasMany = options.length > 1;

    void step(int delta) {
      final next = (current + delta) % options.length;
      notifier.selectLyricsProvider(options[next].provider);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          _Pill(
            children: [
              if (hasMany)
                _PillIcon(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Previous provider',
                  onPressed: () => step(options.length - 1),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: hasMany ? () => showLyricsProviderSheet(context) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          options[current].provider,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (hasMany) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${current + 1}/${options.length}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                        const Icon(
                          Icons.expand_more_rounded,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (hasMany)
                _PillIcon(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Next provider',
                  onPressed: () => step(1),
                ),
            ],
          ),
          if (view.isSynced)
            _Pill(
              children: [
                _PillIcon(
                  icon: Icons.remove_rounded,
                  tooltip: 'Show lyrics earlier',
                  onPressed: () =>
                      notifier.setLyricsOffset(view.offset - _step),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showLyricsOffsetSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: Colors.white54,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatLyricsOffset(view.offset),
                          style: TextStyle(
                            color: view.offset == 0
                                ? Colors.white70
                                : LinerColors.accentSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _PillIcon(
                  icon: Icons.add_rounded,
                  tooltip: 'Show lyrics later',
                  onPressed: () =>
                      notifier.setLyricsOffset(view.offset + _step),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: children),
  );
}

class _PillIcon extends StatelessWidget {
  const _PillIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    padding: EdgeInsets.zero,
    icon: Icon(icon, color: Colors.white70, size: 18),
    onPressed: onPressed,
  );
}

Future<void> showLyricsProviderSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: LinerColors.darkElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _ProviderSheet(),
  );
}

class _ProviderSheet extends ConsumerWidget {
  const _ProviderSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(
      playerStateProvider.select((s) => s.lyricsOptions),
    );
    final active = ref.watch(
      playerStateProvider.select((s) => s.activeLyricsProvider),
    );
    final notifier = ref.read(playerStateProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Lyrics source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          for (final (index, option) in options.indexed)
            ListTile(
              leading: SizedBox(
                width: 24,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white38),
                ),
              ),
              title: Text(
                option.provider,
                style: TextStyle(
                  color: option.provider == active
                      ? Colors.white
                      : Colors.white70,
                  fontWeight: option.provider == active
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              subtitle: Text(
                option.syncLevel.label,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              trailing: option.provider == active
                  ? const Icon(
                      Icons.check_rounded,
                      color: LinerColors.accentPrimary,
                    )
                  : null,
              onTap: () {
                notifier.selectLyricsProvider(option.provider);
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

Future<void> showLyricsOffsetSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: LinerColors.darkElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _OffsetSheet(),
  );
}

class _OffsetSheet extends ConsumerWidget {
  const _OffsetSheet();

  static const _presets = [-1000, -500, -200, -100, 100, 200, 500, 1000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset = ref.watch(
      playerStateProvider.select((s) => s.lyricsOffsetMs),
    );
    final notifier = ref.read(playerStateProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Lyrics timing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: offset == 0
                      ? null
                      : () => notifier.setLyricsOffset(0),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Use + if the lyrics appear too early and - if they are late. '
              'Saved for this song.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Earlier by 50 ms',
                  icon: const Icon(Icons.remove_rounded),
                  onPressed: () => notifier.setLyricsOffset(offset - 50),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    formatLyricsOffset(offset),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Later by 50 ms',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => notifier.setLyricsOffset(offset + 50),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final delta in _presets)
                  ActionChip(
                    backgroundColor: LinerColors.darkPanel,
                    side: BorderSide.none,
                    label: Text(
                      '${delta > 0 ? '+' : ''}${delta / 1000}s',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onPressed: () => notifier.setLyricsOffset(offset + delta),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
