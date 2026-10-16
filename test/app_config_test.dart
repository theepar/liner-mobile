import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/config/app_config.dart';

void main() {
  test('AppConfig.clientVersion matches the pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([\d.]+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);

    expect(version, AppConfig.clientVersion);
  });

  test('share links and deep links use the Liner schemes', () {
    expect(
      AppConfig.shareUrl('playlist', 'p1'),
      'https://link.tryliner.fun/playlist?id=p1',
    );
    expect(AppConfig.deepLink('artist', 'UC1'), 'liner://artist?id=UC1');
  });
}
