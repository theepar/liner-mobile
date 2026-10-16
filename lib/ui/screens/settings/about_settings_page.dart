import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../providers/app_info_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/liner_logo.dart';
import 'settings_widgets.dart';

class AboutSettingsPage extends ConsumerWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).asData?.value;
    final version = info?.version ?? AppConfig.clientVersion;
    final build = info?.buildNumber;
    final buildKind = kReleaseMode ? 'Release build' : 'Debug build';

    Widget link(IconData icon, String title, String url) => SettingsNavTile(
      icon: icon,
      title: title,
      external: true,
      onTap: () => openExternalLink(context, ref, url),
    );

    return SettingsPage(
      title: 'About',
      description: 'Version and community links.',
      children: [
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const LinerLogoTile(size: 72),
                  const SizedBox(height: 14),
                  const Text(
                    'Liner',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    build == null || build.isEmpty
                        ? 'Version $version'
                        : 'Version $version (build $build)',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    buildKind,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Modern music streaming player with syllable-synced lyrics.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SettingsHeading('Community & resources'),
        SettingsCard(
          children: [
            link(Icons.campaign_outlined, 'Channel', AppConfig.channelUrl),
            link(Icons.support_agent_rounded, 'Support', AppConfig.supportUrl),
            link(Icons.code_rounded, 'GitHub', AppConfig.githubUrl),
            link(Icons.language_rounded, 'Website', AppConfig.websiteUrl),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Distributed under Liner Source-Available & Non-Commercial '
            'License.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}
