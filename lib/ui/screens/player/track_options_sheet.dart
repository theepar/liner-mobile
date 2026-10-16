import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/track.dart';
import '../../../core/theme/app_theme.dart';
import '../../utils/ui_helpers.dart';

Future<void> showTrackOptionsSheet(BuildContext context, Track track) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: LinerColors.darkElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share_rounded, color: Colors.white),
            title: const Text(
              'Copy Song Link',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              track.shareUrl,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await Clipboard.setData(ClipboardData(text: track.shareUrl));
              if (context.mounted) showMessage(context, 'Link copied');
            },
          ),
        ],
      ),
    ),
  );
}
