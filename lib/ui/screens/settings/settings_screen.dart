import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/branding_variant.dart';
import '../../../core/models/liner_user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/dark_input.dart';
import 'about_settings_page.dart';
import 'appearance_settings_page.dart';
import 'audio_settings_page.dart';
import 'playback_settings_page.dart';
import 'settings_widgets.dart';
import 'storage_settings_page.dart';

class SettingsDestination {
  const SettingsDestination({
    required this.title,
    required this.description,
    required this.icon,
    required this.page,
    required this.topics,
  });

  final String title;
  final String description;
  final IconData icon;
  final Widget Function() page;
  final List<String> topics;
}

final settingsDestinations = <SettingsDestination>[
  const SettingsDestination(
    title: 'Playback',
    description: 'Queue behavior and tap actions',
    icon: Icons.play_circle_outline_rounded,
    page: PlaybackSettingsPage.new,
    topics: [
      'Autoplay similar tracks',
      'Tap on a song',
      'Play instantly',
      'Add to queue',
    ],
  ),
  const SettingsDestination(
    title: 'Audio',
    description: 'Streaming quality and connection',
    icon: Icons.graphic_eq_rounded,
    page: AudioSettingsPage.new,
    topics: [
      'Streaming quality',
      'Standard quality',
      'High quality',
      'Opus',
      'AAC',
      'Connection',
      'API server',
      'Primary Official API',
      'Edge Relay Backup',
      'Test connection',
      'Probe',
    ],
  ),
  SettingsDestination(
    title: 'Appearance',
    description: 'Logo branding and player background',
    icon: Icons.palette_outlined,
    page: AppearanceSettingsPage.new,
    topics: [
      'Branding',
      'Logo',
      for (final variant in BrandingVariant.values) variant.label,
      'Animated background',
    ],
  ),
  const SettingsDestination(
    title: 'Cache & Storage',
    description: 'Storage usage and clearing the cache',
    icon: Icons.storage_rounded,
    page: StorageSettingsPage.new,
    topics: ['Storage usage', 'Clear cache', 'Cover artwork', 'Search history'],
  ),
  const SettingsDestination(
    title: 'About',
    description: 'Version and community links',
    icon: Icons.info_outline_rounded,
    page: AboutSettingsPage.new,
    topics: [
      'Version',
      'Build',
      'Channel',
      'Support',
      'GitHub',
      'Website',
      'License',
    ],
  ),
];

class _SearchHit {
  const _SearchHit(this.title, this.destination);

  final String title;
  final SettingsDestination destination;
}

List<_SearchHit> _search(String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  return [
    for (final destination in settingsDestinations) ...[
      if (destination.title.toLowerCase().contains(needle))
        _SearchHit(destination.title, destination),
      for (final topic in destination.topics)
        if (topic.toLowerCase().contains(needle))
          _SearchHit(topic, destination),
    ],
  ];
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LinerColors.darkElevated,
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authProvider.notifier).signOut();
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LinerColors.darkElevated,
        title: const Text('Reset to defaults'),
        content: const Text(
          'Playback, audio quality and appearance go back to their defaults. '
          'Your account and chosen server stay as they are.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await ref.read(settingsProvider.notifier).resetPreferences();
    if (mounted) showMessage(context, 'Settings reset to defaults');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final hits = _search(_query);
    final isSearching = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 28,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage your preferences',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Colors.white),
              decoration: darkInputDecoration(
                hint: 'Search settings...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white38,
                ),
                suffix: isSearching
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            if (isSearching)
              _SearchResults(hits: hits)
            else ...[
              if (user != null)
                SettingsCard(
                  children: [
                    _AccountTile(user: user, onSignOut: _confirmSignOut),
                  ],
                ),
              const SettingsHeading('Preferences'),
              SettingsCard(
                children: [
                  for (final destination in settingsDestinations.take(3))
                    _DestinationTile(destination: destination),
                ],
              ),
              const SettingsHeading('Application'),
              SettingsCard(
                children: [
                  for (final destination in settingsDestinations.skip(3))
                    _DestinationTile(destination: destination),
                ],
              ),
              const SettingsHeading('Help'),
              SettingsCard(
                children: [
                  SettingsNavTile(
                    icon: Icons.menu_book_outlined,
                    title: 'Docs',
                    description: 'Guides and how Liner is built',
                    external: true,
                    onTap: () =>
                        openExternalLink(context, ref, AppConfig.docsUrl),
                  ),
                  SettingsNavTile(
                    icon: Icons.support_agent_rounded,
                    title: 'Support',
                    description: 'Ask a question or report a problem',
                    external: true,
                    onTap: () =>
                        openExternalLink(context, ref, AppConfig.supportUrl),
                  ),
                ],
              ),
              Center(
                child: TextButton(
                  onPressed: _confirmReset,
                  child: const Text(
                    'Reset to defaults',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination});

  final SettingsDestination destination;

  @override
  Widget build(BuildContext context) => SettingsNavTile(
    icon: destination.icon,
    title: destination.title,
    description: destination.description,
    onTap: () => openSettingsPage(context, destination.page()),
  );
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.hits});

  final List<_SearchHit> hits;

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: Colors.white24, size: 44),
            SizedBox(height: 12),
            Text(
              'No settings match your search',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return SettingsCard(
      children: [
        for (final hit in hits)
          SettingsNavTile(
            icon: hit.destination.icon,
            title: hit.title,
            description: hit.destination.title,
            onTap: () => openSettingsPage(context, hit.destination.page()),
          ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.user, required this.onSignOut});

  final LinerUser user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl;
    final username = user.username;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: LinerColors.accentPrimary,
        backgroundImage: hasAvatar
            ? CachedNetworkImageProvider(avatarUrl)
            : null,
        child: hasAvatar
            ? null
            : Text(
                user.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
      title: Text(
        user.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        username != null && username.isNotEmpty
            ? '@$username'
            : user.email ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: TextButton(
        onPressed: onSignOut,
        child: const Text(
          'Sign Out',
          style: TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ),
    );
  }
}
