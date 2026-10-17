import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'cover_image_cache.dart';

class AudioCache implements DeviceCache {
  const AudioCache();

  Future<Directory> get _directory async {
    final temporary = await getTemporaryDirectory();
    final directory = Directory(
      '${temporary.path}${Platform.pathSeparator}liner_audio',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> fileForUrl(String url) async {
    var hash = 0x811c9dc5;
    for (final codeUnit in url.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return File(
      '${(await _directory).path}${Platform.pathSeparator}$hash.media',
    );
  }

  @override
  Future<int> sizeBytes() async {
    final directory = await _directory;
    var total = 0;
    await for (final entity in directory.list()) {
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
    final directory = await _directory;
    await for (final entity in directory.list()) {
      try {
        await entity.delete();
      } on FileSystemException {
        continue;
      }
    }
  }
}
