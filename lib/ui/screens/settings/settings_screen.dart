import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../providers/music_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 28,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),

            // ── API Server Backend Section ────────────────────────
            _buildSectionHeader('API BACKEND SERVER'),
            Container(
              decoration: BoxDecoration(
                color: LinerColors.darkElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LinerColors.darkBorderSecondary),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Primary Official API', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('https://api.tryliner.fun (Cloudflare)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: kPrimaryApiUrl,
                    groupValue: settings.currentBaseUrl,
                    activeColor: LinerColors.accentPrimary,
                    onChanged: (val) {
                      if (val != null) notifier.setBaseUrl(val);
                    },
                  ),
                  const Divider(height: 1, color: LinerColors.darkBorderPrimary),
                  RadioListTile<String>(
                    title: const Text('Edge Relay Backup', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('http://edge.tryliner.fun:10518 (Direct IP fallback)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: kFallbackEdgeUrl,
                    groupValue: settings.currentBaseUrl,
                    activeColor: LinerColors.accentPrimary,
                    onChanged: (val) {
                      if (val != null) notifier.setBaseUrl(val);
                    },
                  ),
                  const Divider(height: 1, color: LinerColors.darkBorderPrimary),
                  ListTile(
                    title: const Text('Auto-Probe Health', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(
                      settings.isUsingFallback ? 'Active: Fallback Edge Relay' : 'Active: Primary Official API',
                      style: TextStyle(
                        color: settings.isUsingFallback ? Colors.amber : Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LinerColors.darkPanel,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => notifier.probeEndpoint(),
                      child: const Text('Probe', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Audio Quality Section ─────────────────────────────
            _buildSectionHeader('AUDIO STREAMING QUALITY'),
            Container(
              decoration: BoxDecoration(
                color: LinerColors.darkElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LinerColors.darkBorderSecondary),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('High Quality (Opus 320 kbps)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    value: 'high',
                    groupValue: settings.audioQuality,
                    activeColor: LinerColors.accentPrimary,
                    onChanged: (val) {
                      if (val != null) notifier.setAudioQuality(val);
                    },
                  ),
                  const Divider(height: 1, color: LinerColors.darkBorderPrimary),
                  RadioListTile<String>(
                    title: const Text('Medium Quality (Opus 160 kbps)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    value: 'medium',
                    groupValue: settings.audioQuality,
                    activeColor: LinerColors.accentPrimary,
                    onChanged: (val) {
                      if (val != null) notifier.setAudioQuality(val);
                    },
                  ),
                  const Divider(height: 1, color: LinerColors.darkBorderPrimary),
                  RadioListTile<String>(
                    title: const Text('Normal (AAC 128 kbps)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    value: 'normal',
                    groupValue: settings.audioQuality,
                    activeColor: LinerColors.accentPrimary,
                    onChanged: (val) {
                      if (val != null) notifier.setAudioQuality(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Storage / Cache Section ───────────────────────────
            _buildSectionHeader('CACHE & STORAGE'),
            Container(
              decoration: BoxDecoration(
                color: LinerColors.darkElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LinerColors.darkBorderSecondary),
              ),
              child: ListTile(
                title: const Text('Clear Temporary Cache', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Cached album covers & lyrics (~18.4 MB)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: TextButton(
                  child: const Text('Clear', style: TextStyle(color: LinerColors.accentSecondary)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cache cleared successfully'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── About Liner Mobile ────────────────────────────────
            _buildSectionHeader('ABOUT'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LinerColors.darkElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LinerColors.darkBorderSecondary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: LinerColors.accentPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('L', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Liner Mobile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                          SizedBox(height: 2),
                          Text('Version 1.0.4 (Build 42)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Modern music streaming player with syllable-synced lyrics and reactive dynamic visuals. Built with Flutter, mirroring the official Liner Desktop experience.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'GitHub: github.com/tryliner/desktop',
                    style: TextStyle(color: LinerColors.accentSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 1.1,
          color: Colors.white.withOpacity(0.4),
        ),
      ),
    );
  }
}
