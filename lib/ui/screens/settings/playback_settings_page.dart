import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/settings_provider.dart';
import 'settings_widgets.dart';

class PlaybackSettingsPage extends ConsumerWidget {
  const PlaybackSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SettingsPage(
      title: 'Playback',
      description: 'Queue behavior and what happens when you tap a song.',
      children: [
        SettingsCard(
          children: [
            SettingsSwitchTile(
              title: 'Autoplay similar tracks',
              description:
                  'Automatically add similar songs when your queue ends.',
              value: settings.autoplaySimilar,
              onChanged: (enabled) =>
                  notifier.setAutoplaySimilar(enabled: enabled),
            ),
          ],
        ),
        const SettingsHeading(
          'Tap on a song',
          description: 'Choose what happens when you tap a song in a list.',
        ),
        SettingsChoiceCard<TrackTapAction>(
          value: settings.trackTapAction,
          onChanged: notifier.setTrackTapAction,
          options: const [
            SettingsOption(value: TrackTapAction.play, title: 'Play instantly'),
            SettingsOption(
              value: TrackTapAction.queue,
              title: 'Add to queue',
              description:
                  'Starts playing only when nothing is playing yet. '
                  'Use the song menu to play one right away.',
            ),
          ],
        ),
      ],
    );
  }
}
