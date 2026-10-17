import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/playlist_import.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/import_provider.dart';
import '../../../providers/player_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/status_views.dart';

String _reasonLabel(String reason) => switch (reason) {
  'ambiguous_match' => 'Multiple matches',
  'duration_mismatch' => 'Different length',
  'catalog_lookup_failed' => 'Lookup failed',
  'auto_matched' => 'Matched',
  _ => 'Low confidence',
};

class ImportReviewScreen extends ConsumerStatefulWidget {
  const ImportReviewScreen({super.key});

  @override
  ConsumerState<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends ConsumerState<ImportReviewScreen> {
  List<ImportReview>? _items;
  Map<String, bool> _approvals = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ref
        .read(importControllerProvider.notifier)
        .loadReviews();
    if (!mounted) return;
    setState(() {
      _items = items;
      _approvals = {for (final item in items) item.id: true};
    });
  }

  void _setAll({required bool approved}) => setState(() {
    _approvals = {
      for (final item in _items ?? const <ImportReview>[]) item.id: approved,
    };
  });

  Future<void> _submit({required bool skip}) async {
    final items = _items;
    if (items == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    final controller = ref.read(importControllerProvider.notifier);
    try {
      if (skip || items.isEmpty) {
        await controller.skipReview();
      } else {
        await controller.submitReview(items, _approvals);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showMessage(context, 'Could not finish the import. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final selected = _approvals.values.where((approved) => approved).length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Review matches'),
      ),
      body: items == null
          ? const LoadingView(height: 300)
          : items.isEmpty
          ? _NothingToReview(
              isBusy: _isSubmitting,
              onFinish: () => _submit(skip: true),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "We weren't sure about these tracks. Choose the "
                          'matches to add. $selected of ${items.length} selected.',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _setAll(approved: selected != items.length),
                        child: Text(
                          selected == items.length ? 'None' : 'All',
                          style: const TextStyle(
                            color: LinerColors.accentSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ReviewCard(
                        item: item,
                        isApproved: _approvals[item.id] ?? false,
                        onChanged: (value) =>
                            setState(() => _approvals[item.id] = value),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _submit(skip: true),
                          child: const Text(
                            'Skip all',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: LinerColors.accentPrimary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () => _submit(skip: false),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  selected == 0
                                      ? 'Finish'
                                      : 'Add $selected ${selected == 1 ? 'match' : 'matches'}',
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _NothingToReview extends StatelessWidget {
  const _NothingToReview({required this.isBusy, required this.onFinish});

  final bool isBusy;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EmptyView(
            icon: Icons.check_circle_outline_rounded,
            message: 'Nothing needs your review.',
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LinerColors.accentPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: isBusy ? null : onFinish,
            child: const Text('Finish import'),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({
    required this.item,
    required this.isApproved,
    required this.onChanged,
  });

  final ImportReview item;
  final bool isApproved;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposed = item.proposed!;
    final isCurrent = ref.watch(
      currentTrackIdProvider.select((id) => id == proposed.id),
    );
    final isPlaying =
        isCurrent && ref.watch(playerStateProvider.select((s) => s.isPlaying));
    final player = ref.read(playerStateProvider.notifier);
    final duration = item.source.durationMs;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LinerColors.darkElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproved
              ? LinerColors.accentPrimary.withValues(alpha: 0.5)
              : LinerColors.darkBorderSecondary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    item.source.title,
                    if (item.source.artistName.isNotEmpty)
                      item.source.artistName,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (duration != null && duration > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    formatDuration(Duration(milliseconds: duration)),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _reasonLabel(item.reason),
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CoverImage(
                  url: proposed.coverUrl,
                  fallbackUrl: proposed.coverFallbackUrl,
                  width: 44,
                  height: 44,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposed.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      proposed.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isPlaying ? 'Pause preview' : 'Play preview',
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_rounded
                      : Icons.play_circle_rounded,
                  color: Colors.white70,
                  size: 30,
                ),
                onPressed: () => isCurrent
                    ? player.togglePlayPause()
                    : player.playTrack(proposed),
              ),
              Switch(
                value: isApproved,
                activeThumbColor: Colors.white,
                activeTrackColor: LinerColors.accentPrimary,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
