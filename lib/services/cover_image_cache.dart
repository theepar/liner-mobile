import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

/// Something the app keeps on this device that can be measured and cleared.
abstract interface class DeviceCache {
  Future<int> sizeBytes();

  Future<void> clear();
}

/// Cover artwork downloaded by `CachedNetworkImage`.
class CoverImageCache implements DeviceCache {
  const CoverImageCache();

  @override
  Future<int> sizeBytes() async {
    final temp = await getTemporaryDirectory();
    final directory = Directory(
      '${temp.path}${Platform.pathSeparator}${DefaultCacheManager.key}',
    );
    if (!await directory.exists()) return 0;

    var total = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) continue;
      try {
        total += await entity.length();
      } on FileSystemException {
        continue;
      }
    }
    return total;
  }

  @override
  Future<void> clear() async {
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }
}
