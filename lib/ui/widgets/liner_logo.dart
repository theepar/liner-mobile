import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The official Liner mark (`assets/branding/logo.svg`, from tryliner/desktop).
class LinerLogo extends StatelessWidget {
  const LinerLogo({super.key, this.size = 32, this.color = Colors.white});

  static const assetPath = 'assets/branding/logo.svg';

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    assetPath,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    semanticsLabel: 'Liner',
  );
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
