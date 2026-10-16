import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/playlist_import.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/import_provider.dart';
import '../../navigation/navigation_helpers.dart';
import 'import_review_screen.dart';

/// The state of the playlist import in progress (or just finished).
class ImportProgressCard extends ConsumerWidget {
  const ImportProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importControllerProvider);
    final job = state.job;
    if (job == null && !state.isStarting && state.error == null) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(importControllerProvider.notifier);
    final navigator = Navigator.of(context);
    final status = job?.status;
    final hasFailed = state.error != null || status == ImportStatus.failed;
    final isDone = status == ImportStatus.completed && !hasFailed;
    final needsReview = status == ImportStatus.awaitingDecision;

    final title = job?.title ?? 'Importing playlist';
    final subtitle = hasFailed
        ? (state.error ?? job?.errorMessage ?? 'The import failed.')
        : switch (status) {
            null => 'Starting import…',
            ImportStatus.queued =>
              job?.queuePosition == null
                  ? 'Waiting in the queue…'
                  : 'In the queue · position ${job!.queuePosition}',
            ImportStatus.running => 'Matching tracks…',
            ImportStatus.awaitingDecision => 'Some tracks need your review',
            ImportStatus.finalizing => 'Creating your playlist…',
            ImportStatus.completed =>
              job?.result == null
                  ? 'Your playlist is ready'
                  : 'Imported ${job!.result!.imported} of ${job.result!.total} tracks',
            ImportStatus.failed => 'The import failed.',
          };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LinerColors.darkElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasFailed
              ? Colors.redAccent.withValues(alpha: 0.5)
              : LinerColors.darkBorderSecondary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (hasFailed)
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent)
              else if (isDone)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                )
              else if (needsReview)
                const Icon(
                  Icons.rate_review_rounded,
                  color: LinerColors.accentPrimary,
                )
              else
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: LinerColors.accentPrimary,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: hasFailed ? Colors.redAccent : Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDone || hasFailed)
                IconButton(
                  tooltip: 'Dismiss',
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: controller.dismiss,
                ),
            ],
          ),
          if (needsReview) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: LinerColors.accentPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ImportReviewScreen(),
                  ),
                ),
                child: const Text('Review matches'),
              ),
            ),
          ],
          if (isDone && job?.playlistId != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: LinerColors.accentPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final id = job!.playlistId!;
                  controller.dismiss();
                  openUserPlaylist(navigator, id);
                },
                child: const Text('Open playlist'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
