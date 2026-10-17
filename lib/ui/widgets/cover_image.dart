import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.fallbackUrl,
    this.width,
    this.height,
    this.iconSize = 20,
    this.backgroundColor = LinerColors.darkElevated,
    this.iconColor = LinerColors.darkTextTertiary,
  });

  final String url;
  final String? fallbackUrl;
  final double? width;
  final double? height;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _box(withIcon: true);
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, _) => _box(),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    final fallback = fallbackUrl;
    if (fallback == null || fallback.isEmpty) return _box(withIcon: true);
    return CachedNetworkImage(
      imageUrl: fallback,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, _) => _box(),
      errorWidget: (_, _, _) => _box(withIcon: true),
    );
  }

  Widget _box({bool withIcon = false}) => Container(
    width: width,
    height: height,
    color: backgroundColor,
    child: withIcon
        ? Icon(Icons.music_note, size: iconSize, color: iconColor)
        : null,
  );
}
