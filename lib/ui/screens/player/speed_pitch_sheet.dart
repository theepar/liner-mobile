import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/player_provider.dart';

Future<void> showSpeedPitchSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: LinerColors.darkElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SpeedPitchSheet(),
  );
}

class _SpeedPitchSheet extends ConsumerWidget {
  const _SpeedPitchSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(playerStateProvider.select((s) => s.playbackSpeed));
    final pitch = ref.watch(playerStateProvider.select((s) => s.pitch));
    final notifier = ref.read(playerStateProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Speed & Pitch Controls',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _LabeledSlider(
              label: 'Playback Speed',
              value: speed,
              min: 0.5,
              max: 2,
              divisions: 15,
              onChanged: notifier.setSpeed,
            ),
            const SizedBox(height: 12),
            _LabeledSlider(
              label: 'Pitch Key Shift',
              value: pitch,
              min: 0.5,
              max: 1.5,
              divisions: 10,
              onChanged: notifier.setPitch,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                child: const Text(
                  'Reset to Normal (1.0x)',
                  style: TextStyle(color: LinerColors.accentSecondary),
                ),
                onPressed: () {
                  notifier
                    ..setSpeed(1)
                    ..setPitch(1);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(
              '${value.toStringAsFixed(2)}x',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: LinerColors.accentPrimary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
