import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/player_provider.dart';
import '../../widgets/cover_image.dart';

Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: LinerColors.darkElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _QueueSheet(),
  );
}

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(playerStateProvider.select((s) => s.queue));
    final currentIndex = ref.watch(
      playerStateProvider.select((s) => s.currentIndex),
    );
    final notifier = ref.read(playerStateProvider.notifier);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              'Playing Queue (${queue.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final track = queue[index];
                final isCurrent = index == currentIndex;
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CoverImage(
                      url: track.coverUrl,
                      fallbackUrl: track.coverFallbackUrl,
                      width: 40,
                      height: 40,
                    ),
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent
                          ? LinerColors.accentPrimary
                          : Colors.white,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: isCurrent
                      ? const Icon(
                          Icons.volume_up_rounded,
                          color: LinerColors.accentPrimary,
                        )
                      : null,
                  onTap: () {
                    notifier.playTrack(track, queue, index);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
