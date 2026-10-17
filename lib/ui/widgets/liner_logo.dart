import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/branding_variant.dart';
import '../../providers/settings_provider.dart';

class LinerLogo extends ConsumerWidget {
  const LinerLogo({super.key, this.size = 32, this.variant});

  final double size;
  final BrandingVariant? variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(settingsProvider.select((s) => s.branding));
    return SvgPicture.asset(
      (variant ?? selected).assetPath,
      height: size,
      semanticsLabel: 'Liner',
    );
  }
}

class LinerLogoTile extends StatelessWidget {
  const LinerLogoTile({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF0D0D10),
      borderRadius: BorderRadius.circular(size * 0.22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    alignment: Alignment.center,
    child: LinerLogo(size: size * 0.5),
  );
}
