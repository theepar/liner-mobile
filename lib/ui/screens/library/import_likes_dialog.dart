import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/import_source.dart';
import '../../../providers/import_provider.dart';
import '../../widgets/dark_input.dart';

/// Imports a SoundCloud user's liked tracks as a playlist.
Future<void> showImportLikesDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _ImportLikesDialog(),
);

class _ImportLikesDialog extends ConsumerStatefulWidget {
  const _ImportLikesDialog();

  @override
  ConsumerState<_ImportLikesDialog> createState() => _ImportLikesDialogState();
}

class _ImportLikesDialogState extends ConsumerState<_ImportLikesDialog> {
  final _username = TextEditingController();
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final value = _username.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Enter a SoundCloud username');
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await ref
          .read(importControllerProvider.notifier)
          .start(ImportSources.soundCloudLikesUrl(value));
      if (mounted) Navigator.of(context).pop();
    } on ApiException {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _error = 'Could not start the import. Check the username.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LinerColors.darkElevated,
      title: const Text(
        'Import SoundCloud likes',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter a public SoundCloud username to import their liked tracks.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _username,
            enabled: !_isBusy,
            autofocus: true,
            maxLength: 100,
            autocorrect: false,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _import(),
            style: const TextStyle(color: Colors.white),
            decoration: darkInputDecoration(
              hint: 'SoundCloud username',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LinerColors.accentPrimary,
            foregroundColor: Colors.white,
          ),
          onPressed: _isBusy ? null : _import,
          child: _isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Import'),
        ),
      ],
    );
  }
}
