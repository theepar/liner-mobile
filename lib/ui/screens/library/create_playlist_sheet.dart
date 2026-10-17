import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/playlist.dart';
import '../../../core/models/track.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/import_source.dart';
import '../../../providers/api_provider.dart';
import '../../../providers/import_provider.dart';
import '../../../providers/library_provider.dart';
import '../../widgets/dark_input.dart';

enum CreatePlaylistTab { scratch, import }

Future<Playlist?> showCreatePlaylistSheet(
  BuildContext context, {
  CreatePlaylistTab tab = CreatePlaylistTab.scratch,
  String? initialUrl,
  Track? pendingTrack,
}) {
  return showModalBottomSheet<Playlist>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: LinerColors.darkSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CreatePlaylistSheet(
      initialTab: initialUrl == null ? tab : CreatePlaylistTab.import,
      initialUrl: initialUrl,
      pendingTrack: pendingTrack,
    ),
  );
}

class _CreatePlaylistSheet extends ConsumerStatefulWidget {
  const _CreatePlaylistSheet({
    required this.initialTab,
    this.initialUrl,
    this.pendingTrack,
  });

  final CreatePlaylistTab initialTab;
  final String? initialUrl;
  final Track? pendingTrack;

  @override
  ConsumerState<_CreatePlaylistSheet> createState() =>
      _CreatePlaylistSheetState();
}

class _CreatePlaylistSheetState extends ConsumerState<_CreatePlaylistSheet> {
  late CreatePlaylistTab _tab = widget.initialTab;
  late final _link = TextEditingController(text: widget.initialUrl ?? '');
  final _title = TextEditingController();
  final _description = TextEditingController();

  bool _showDescription = false;
  bool _busy = false;
  String? _error;

  bool get _isScratch => _tab == CreatePlaylistTab.scratch;

  @override
  void dispose() {
    _link.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _setTab(CreatePlaylistTab tab) {
    if (_busy) return;
    setState(() {
      _tab = tab;
      _error = null;
    });
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a playlist name');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final api = ref.read(linerApiProvider);
    final description = _description.text.trim();
    try {
      final playlist = await api.createPlaylist(
        title,
        description: description.isEmpty ? null : description,
      );
      ref.invalidate(userPlaylistsProvider);

      final track = widget.pendingTrack;
      var addFailed = false;
      if (track != null) {
        try {
          await api.addTrackToPlaylist(playlist.id, track.id);
        } on ApiException {
          addFailed = true;
        }
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(playlist);
      if (track != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              addFailed
                  ? 'Playlist created, but the track could not be added.'
                  : 'Added to ${playlist.title}',
            ),
          ),
        );
      }
    } on ApiException {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not create the playlist. Try again.';
        });
      }
    }
  }

  Future<void> _import() async {
    final raw = _link.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Paste a link first');
      return;
    }
    final uri = ImportSources.normalize(raw);
    if (uri == null) {
      setState(() => _error = "That link isn't supported");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(importControllerProvider.notifier).start(uri.toString());
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (error.statusCode) {
          null => 'Cannot reach the server. Check your connection.',
          400 || 404 || 422 => "That link isn't supported",
          429 => 'Too many imports. Try again in a moment.',
          _ => 'Could not start the import. Try again.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detected = _isScratch ? null : ImportSources.detect(_link.text);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isScratch ? 'From scratch' : 'Import a playlist',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _isScratch
                  ? 'Create an empty playlist'
                  : 'Import an existing playlist from Spotify or YouTube',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 14),
            SegmentedTabs<CreatePlaylistTab>(
              options: const {
                CreatePlaylistTab.scratch: 'From scratch',
                CreatePlaylistTab.import: 'Import',
              },
              selected: _tab,
              onChanged: _setTab,
            ),
            const SizedBox(height: 14),
            if (_isScratch) ..._scratchFields() else ..._importFields(detected),
            if (_error case final error?) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(
                  color: LinerColors.accentPrimary,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LinerColors.accentPrimary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _busy ? null : (_isScratch ? _create : _import),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isScratch ? 'Create' : 'Import'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _scratchFields() => [
    TextField(
      controller: _title,
      enabled: !_busy,
      autofocus: true,
      maxLength: PlaylistRules.titleMaxLength,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _create(),
      onChanged: (_) => setState(() => _error = null),
      style: const TextStyle(color: Colors.white),
      decoration: darkInputDecoration(hint: 'Playlist name'),
    ),
    if (_showDescription) ...[
      const SizedBox(height: 10),
      TextField(
        controller: _description,
        enabled: !_busy,
        maxLength: PlaylistRules.descriptionMaxLength,
        maxLines: 2,
        style: const TextStyle(color: Colors.white),
        decoration: darkInputDecoration(hint: 'Description (optional)'),
      ),
    ] else
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() => _showDescription = true),
          child: const Text(
            '+ Description',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ),
  ];

  List<Widget> _importFields(String? detected) => [
    TextField(
      controller: _link,
      enabled: !_busy,
      keyboardType: TextInputType.url,
      autocorrect: false,
      textInputAction: TextInputAction.go,
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      onSubmitted: (_) => _import(),
      onChanged: (_) => setState(() => _error = null),
      style: const TextStyle(color: Colors.white),
      decoration: darkInputDecoration(
        hint: 'Paste a link...',
        prefixIcon: const Icon(Icons.link_rounded, color: Colors.white54),
        suffix: detected != null
            ? Tooltip(
                message: detected,
                child: const Icon(
                  Icons.check_rounded,
                  color: LinerColors.accentPrimary,
                ),
              )
            : const Tooltip(
                message: ImportSources.supportedHint,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: Duration(seconds: 4),
                child: Icon(Icons.info_outline_rounded, color: Colors.white38),
              ),
      ),
    ),
    const SizedBox(height: 8),
    Text(
      detected == null ? ImportSources.supportedHint : 'Detected: $detected',
      style: const TextStyle(color: Colors.white38, fontSize: 12),
    ),
  ];
}
