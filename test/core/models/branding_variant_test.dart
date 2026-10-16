import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/models/branding_variant.dart';

void main() {
  group('BrandingVariant', () {
    test('offers the thirteen variants the desktop app has', () {
      expect(BrandingVariant.values.map((v) => v.label), [
        'Default',
        'Spotify',
        'Discord',
        'Telegram',
        'Aurora',
        'Sunset',
        'Ocean',
        'Forest',
        'Berry',
        'Carbon',
        'Pixel',
        'Scanlines',
        'Chrome',
      ]);
    });

    test('every variant has a bundled logo file', () {
      for (final variant in BrandingVariant.values) {
        expect(
          File(variant.assetPath).existsSync(),
          isTrue,
          reason: variant.assetPath,
        );
      }
    });

    test('ids are unique', () {
      final ids = BrandingVariant.values.map((v) => v.id).toSet();

      expect(ids, hasLength(BrandingVariant.values.length));
    });

    test('is found again by its id', () {
      for (final variant in BrandingVariant.values) {
        expect(BrandingVariant.fromId(variant.id), variant);
      }
    });

    test('falls back to the default for an unknown or missing id', () {
      expect(BrandingVariant.fromId('neon'), BrandingVariant.standard);
      expect(BrandingVariant.fromId(null), BrandingVariant.standard);
    });
  });
}
