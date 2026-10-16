import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/connection_report.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/settings_provider.dart';
import 'settings_widgets.dart';

class AudioSettingsPage extends ConsumerWidget {
  const AudioSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SettingsPage(
      title: 'Audio',
      description: 'Streaming quality and connection diagnostics.',
      children: [
        const SettingsHeading('Streaming quality'),
        if (defaultTargetPlatform == TargetPlatform.iOS)
          const SettingsCard(
            children: [
              ListTile(
                leading: Icon(Icons.graphic_eq_rounded, color: Colors.white70),
                title: Text(
                  'High quality (AAC 256 kbps)',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  'iPhone and iPad can only play AAC, so this is always used.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          )
        else
          SettingsChoiceCard<bool>(
            value: settings.highQualityAudio,
            onChanged: (high) => notifier.setHighQualityAudio(enabled: high),
            options: const [
              SettingsOption(
                value: false,
                title: 'Standard',
                description: 'Opus 64 kbps. Uses less data.',
              ),
              SettingsOption(
                value: true,
                title: 'High',
                description: 'AAC 256 kbps. Applies from the next song.',
              ),
            ],
          ),
        const SettingsHeading(
          'Connection',
          description: 'Which Liner server the app talks to.',
        ),
        SettingsChoiceCard<String>(
          value: settings.currentBaseUrl,
          onChanged: notifier.setBaseUrl,
          options: const [
            SettingsOption(
              value: AppConfig.primaryApiUrl,
              title: 'Primary Official API',
              description: AppConfig.primaryApiUrl,
            ),
            SettingsOption(
              value: AppConfig.fallbackApiUrl,
              title: 'Edge Relay Backup',
              description: AppConfig.fallbackApiUrl,
            ),
          ],
        ),
        SettingsCard(
          children: [
            ListTile(
              title: const Text(
                'Choose automatically',
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
              trailing: _SmallButton(
                label: 'Probe',
                onPressed: notifier.probeEndpoint,
              ),
            ),
            const _ConnectionTest(),
          ],
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: LinerColors.darkPanel,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    onPressed: onPressed,
    child: Text(label, style: const TextStyle(fontSize: 12)),
  );
}

class _ConnectionTest extends ConsumerStatefulWidget {
  const _ConnectionTest();

  @override
  ConsumerState<_ConnectionTest> createState() => _ConnectionTestState();
}

class _ConnectionTestState extends ConsumerState<_ConnectionTest> {
  ConnectionReport? _report;
  bool _isTesting = false;

  Future<void> _test() async {
    setState(() => _isTesting = true);
    final report = await ref.read(settingsProvider.notifier).checkConnection();
    if (!mounted) return;
    setState(() {
      _report = report;
      _isTesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final reachable = report?.isReachable ?? false;
    final String subtitle;
    if (_isTesting) {
      subtitle = 'Testing...';
    } else if (report == null) {
      subtitle = 'Check that the selected server answers';
    } else if (reachable) {
      subtitle = 'Reachable in ${report.latency?.inMilliseconds} ms';
    } else if (report.statusCode != null) {
      subtitle = 'Server answered with HTTP ${report.statusCode}';
    } else {
      subtitle = '${report.failure ?? 'Unreachable'}. Try the other server.';
    }

    return ListTile(
      title: const Text(
        'Test connection',
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: report == null || _isTesting
              ? Colors.white54
              : (reachable ? Colors.greenAccent : Colors.redAccent),
          fontSize: 12,
        ),
      ),
      trailing: _isTesting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _SmallButton(label: 'Test', onPressed: _test),
    );
  }
}
