import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/collection_type.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/library_provider.dart';
import '../utils/ui_helpers.dart';

/// Adds or removes an album, artist or playlist from the user's library.
class SaveButton extends ConsumerWidget {
  const SaveButton({super.key, required this.type, required this.id});

  final CollectionType type;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(
      savedIdsProvider(type).select((ids) => ids.contains(id)),
    );
    final isArtist = type == CollectionType.artists;
    final label = isSaved
        ? (isArtist ? 'Following' : 'Saved')
        : (isArtist ? 'Follow' : 'Save');

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: isSaved ? LinerColors.accentPrimary : Colors.white,
        side: BorderSide(
          color: isSaved
              ? LinerColors.accentPrimary
              : LinerColors.darkBorderSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      icon: Icon(isSaved ? Icons.check_rounded : Icons.add_rounded, size: 18),
      label: Text(label),
      onPressed: () => toggleSaved(context, ref, type, id),
    );
  }
}
