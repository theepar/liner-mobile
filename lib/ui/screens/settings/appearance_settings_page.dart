import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/branding_variant.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/liner_logo.dart';
import 'settings_widgets.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SettingsPage(
      title: 'Appearance',
      description: 'How Liner looks.',
      children: [
        const SettingsHeading(
          'Branding',
          description: 'Choose the logo style.',
        ),
        _BrandingGrid(
          selected: settings.branding,
          onSelected: notifier.setBranding,
        ),
        const SettingsHeading('Now playing'),
        SettingsCard(
          children: [
            SettingsSwitchTile(
              title: 'Animated background',
              description:
                  'Let the colour glow behind the player move while music '
                  'plays. Turn off to save battery.',
              value: settings.animatedBackground,
              onChanged: (enabled) =>
                  notifier.setAnimatedBackground(enabled: enabled),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandingGrid extends StatelessWidget {
  const _BrandingGrid({required this.selected, required this.onSelected});

  final BrandingVariant selected;
  final ValueChanged<BrandingVariant> onSelected;

  static const _columns = 3;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - _gap * (_columns - 1)) / _columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final variant in BrandingVariant.values)
              SizedBox(
                width: width,
                child: _BrandingTile(
                  variant: variant,
                  isSelected: variant == selected,
                  onTap: () => onSelected(variant),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _BrandingTile extends StatelessWidget {
  const _BrandingTile({
    required this.variant,
    required this.isSelected,
    required this.onTap,
  });

  final BrandingVariant variant;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: isSelected,
    label: variant.label,
    child: Material(
      color: LinerColors.darkElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected
              ? LinerColors.accentPrimary
              : LinerColors.darkBorderSecondary,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              LinerLogo(size: 42, variant: variant),
              const SizedBox(height: 10),
              Text(
                variant.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
