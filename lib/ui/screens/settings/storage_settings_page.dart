import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/storage_provider.dart';
import 'settings_widgets.dart';

const _categoryColors = {
  StorageCategory.covers: LinerColors.accentPrimary,
  StorageCategory.searchHistory: Color(0xFF60A5FA),
};

class StorageSettingsPage extends ConsumerStatefulWidget {
  const StorageSettingsPage({super.key});

  @override
  ConsumerState<StorageSettingsPage> createState() =>
      _StorageSettingsPageState();
}

class _StorageSettingsPageState extends ConsumerState<StorageSettingsPage> {
  final _selected = {...StorageCategory.values};

  Future<void> _clear() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(storageProvider.notifier).clear(_selected);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Cache cleared')));
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageProvider);
    final toClear = storage.bytesIn(_selected);
    final allSelected = _selected.length == StorageCategory.values.length;

    return SettingsPage(
      title: 'Cache & Storage',
      description: 'Storage breakdown and what Liner keeps on this device.',
      children: [
        const SettingsHeading('Storage usage'),
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _UsageDonut(state: storage),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      storage.isLoading
                          ? 'Measuring...'
                          : storage.totalBytes == 0
                          ? 'Cache is squeaky clean!'
                          : 'Liner is currently using '
                                '${formatBytes(storage.totalBytes)} of local '
                                'storage.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Expanded(child: SettingsHeading('Categories')),
            TextButton(
              onPressed: () => setState(() {
                allSelected
                    ? _selected.clear()
                    : _selected.addAll(StorageCategory.values);
              }),
              child: Text(allSelected ? 'Deselect all' : 'Select all'),
            ),
          ],
        ),
        SettingsCard(
          children: [
            for (final category in StorageCategory.values)
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: _categoryColors[category],
                checkColor: Colors.white,
                side: const BorderSide(color: Colors.white38, width: 1.5),
                value: _selected.contains(category),
                onChanged: (checked) => setState(() {
                  (checked ?? false)
                      ? _selected.add(category)
                      : _selected.remove(category);
                }),
                title: Text(
                  category.label,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  category.description,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                secondary: Text(
                  storage.isLoading
                      ? '...'
                      : formatBytes(storage.bytesOf(category)),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LinerColors.accentPrimary,
              disabledBackgroundColor: LinerColors.darkPanel,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: storage.isLoading || storage.isClearing || toClear == 0
                ? null
                : _clear,
            child: storage.isClearing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('Clear Cache (${formatBytes(toClear)})'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 16, 4, 0),
          child: Text(
            'All media, covers and tracks stay in the cloud and are '
            'downloaded again when you need them.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _UsageDonut extends StatelessWidget {
  const _UsageDonut({required this.state});

  final StorageState state;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84,
    height: 84,
    child: CustomPaint(
      painter: _DonutPainter(
        values: [
          for (final category in StorageCategory.values)
            (_categoryColors[category]!, state.bytesOf(category)),
        ],
      ),
      child: Center(
        child: Text(
          state.isLoading ? '' : formatBytes(state.totalBytes),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    ),
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values});

  final List<(Color, int)> values;

  static const _stroke = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;

    canvas.drawCircle(
      rect.center,
      arcRect.width / 2,
      paint..color = LinerColors.darkPanel,
    );

    final total = values.fold(0, (sum, entry) => sum + entry.$2);
    if (total == 0) return;
    var start = -math.pi / 2;
    for (final (color, bytes) in values) {
      if (bytes == 0) continue;
      final sweep = 2 * math.pi * bytes / total;
      canvas.drawArc(arcRect, start, sweep, false, paint..color = color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.values.toString() != values.toString();
}
