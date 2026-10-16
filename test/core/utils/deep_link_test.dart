import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/utils/deep_link.dart';

DeepLinkTarget? parse(String raw) => DeepLinks.parse(Uri.parse(raw));

void main() {
  group('DeepLinks.parse', () {
    test('accepts real share targets', () {
      expect(
        parse('liner://artist?id=UCGtGpOIGHfRu1KYL9pi-mNQ'),
        const DeepLinkTarget(DeepLinkType.artist, 'UCGtGpOIGHfRu1KYL9pi-mNQ'),
      );
      expect(
        parse('liner://album?id=MPREb_xCxkOKReFZv'),
        const DeepLinkTarget(DeepLinkType.album, 'MPREb_xCxkOKReFZv'),
      );
      expect(
        parse('liner://playlist?id=VLPLD8jNKEyHYB2DHh5vXSI4USLFo29vzUYl'),
        const DeepLinkTarget(
          DeepLinkType.playlist,
          'VLPLD8jNKEyHYB2DHh5vXSI4USLFo29vzUYl',
        ),
      );
      expect(
        parse('liner://track?id=RGdkabupfPI'),
        const DeepLinkTarget(DeepLinkType.track, 'RGdkabupfPI'),
      );
    });

    test('is not thrown by the letter case of the type', () {
      expect(
        parse('liner://TRACK?id=RGdkabupfPI'),
        const DeepLinkTarget(DeepLinkType.track, 'RGdkabupfPI'),
      );
    });

    test('ignores unrelated query parameters', () {
      expect(
        parse('liner://artist?id=UCaaaaaaaaaaaaaaaaaaaaaa&x=1&y=2'),
        const DeepLinkTarget(DeepLinkType.artist, 'UCaaaaaaaaaaaaaaaaaaaaaa'),
      );
    });

    test('rejects other schemes and unknown types', () {
      expect(parse('https://evil.com'), isNull);
      expect(parse('https://link.tryliner.fun/track?id=RGdkabupfPI'), isNull);
      expect(parse('javascript:alert(1)'), isNull);
      expect(parse('liner://evil?id=RGdkabupfPI'), isNull);
    });

    test('needs exactly one id', () {
      expect(parse('liner://artist'), isNull);
      expect(parse('liner://artist?id='), isNull);
      expect(
        parse(
          'liner://artist?id=UCaaaaaaaaaaaaaaaaaaaaaa&id=UCbbbbbbbbbbbbbbbbbbbbbb',
        ),
        isNull,
      );
    });

    test('rejects ids that do not look like the type they claim', () {
      expect(parse('liner://track?id=RGdkabupfPIextra'), isNull);
      expect(parse('liner://track?id=short'), isNull);
      expect(parse('liner://artist?id=ABaaaaaaaaaaaaaaaaaaaaaa'), isNull);
      expect(parse('liner://album?id=notanalbum1'), isNull);
      expect(parse('liner://artist?id=UCaaa/../../../../etc'), isNull);
      expect(parse('liner://playlist?id=has space here'), isNull);
    });
  });

  group('DeepLinks.isUserPlaylistId', () {
    test('recognizes uuids and pl- tokens', () {
      expect(
        DeepLinks.isUserPlaylistId('3f2b8c1e-9d4a-4b6e-8a1f-0c7d5e2a9b34'),
        isTrue,
      );
      expect(DeepLinks.isUserPlaylistId('pl-abc12345'), isTrue);
    });

    test('treats everything else as a catalog playlist', () {
      expect(
        DeepLinks.isUserPlaylistId('VLPLD8jNKEyHYB2DHh5vXSI4USLFo29vzUYl'),
        isFalse,
      );
    });
  });
}
