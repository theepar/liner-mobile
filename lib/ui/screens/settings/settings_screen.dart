import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/liner_user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/liner_logo.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final user = ref.watch(authProvider);

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
            const SizedBox(height: 24),
            const _SectionHeader('ACCOUNT'),
            if (user != null)
              _Card(
                child: _AccountTile(
                  user: user,
                  onSignOut: ref.read(authProvider.notifier).signOut,
                ),
              ),
            const SizedBox(height: 24),
            const _SectionHeader('API BACKEND SERVER'),
            _Card(
              child: Column(
                children: [
                  RadioGroup<String>(
                    groupValue: settings.currentBaseUrl,
                    onChanged: (url) {
                      if (url != null) notifier.setBaseUrl(url);
                    },
                    child: const Column(
                      children: [
                        _ServerOption(
                          title: 'Primary Official API',
                          url: AppConfig.primaryApiUrl,
                        ),
                        Divider(
                          height: 1,
                          color: LinerColors.darkBorderPrimary,
                        ),
                        _ServerOption(
                          title: 'Edge Relay Backup',
                          url: AppConfig.fallbackApiUrl,
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    color: LinerColors.darkBorderPrimary,
                  ),
                  ListTile(
                    title: const Text(
                      'Auto-Probe Health',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      settings.isUsingFallback
                          ? 'Active: Edge Relay Backup'
                          : 'Active: Primary Official API',
                      style: TextStyle(
                        color: settings.isUsingFallback
                            ? Colors.amber
                            : Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: _TileButton(
                      label: 'Probe',
                      onPressed: notifier.probeEndpoint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader('CACHE & STORAGE'),
            _Card(
              child: ListTile(
                title: const Text(
                  'Clear Image Cache',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Cached album and artist artwork',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: TextButton(
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: LinerColors.accentSecondary),
                  ),
                  onPressed: () => _clearCache(context),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader('ABOUT'),
            const _Card(child: _AboutTile()),
          ],
        ),
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache.clear();
    if (context.mounted) showMessage(context, 'Image cache cleared');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 1.1,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LinerColors.darkElevated,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: LinerColors.darkBorderSecondary),
      ),
      child: child,
    );
  }
}

class _TileButton extends StatelessWidget {
  const _TileButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: LinerColors.darkPanel,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12)),
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
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: LinerColors.accentPrimary,
        backgroundImage: avatarUrl == null || avatarUrl.isEmpty
            ? null
            : CachedNetworkImageProvider(avatarUrl),
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Text(
                user.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
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

class _ServerOption extends StatelessWidget {
  const _ServerOption({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: url,
      activeColor: LinerColors.accentPrimary,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        url,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              LinerLogoTile(size: 44),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Liner Mobile',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Version ${AppConfig.clientVersion}',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Music streaming with syllable-synced lyrics and reactive dynamic visuals.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'github.com/tryliner',
            style: TextStyle(
              color: LinerColors.accentSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
