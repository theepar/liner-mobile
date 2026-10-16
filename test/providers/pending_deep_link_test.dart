import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/utils/deep_link.dart';
import 'package:liner_mobile/providers/deep_link_provider.dart';
import 'package:liner_mobile/services/deep_link_source.dart';

class FakeDeepLinkSource implements DeepLinkSource {
  final controller = StreamController<Uri>.broadcast();

  @override
  Stream<Uri> get links => controller.stream;

  void emit(String raw) => controller.add(Uri.parse(raw));
}

void main() {
  late FakeDeepLinkSource source;
  late ProviderContainer container;

  setUp(() {
    source = FakeDeepLinkSource();
    container = ProviderContainer(
      overrides: [deepLinkSourceProvider.overrideWithValue(source)],
    );
    addTearDown(container.dispose);
    addTearDown(source.controller.close);
    container.read(pendingDeepLinkProvider);
  });

  Future<void> deliver() => Future<void>.delayed(Duration.zero);

  test('keeps a valid link until it is consumed', () async {
    source.emit('liner://track?id=RGdkabupfPI');
    await deliver();

    expect(
      container.read(pendingDeepLinkProvider),
      const DeepLinkTarget(DeepLinkType.track, 'RGdkabupfPI'),
    );

    container.read(pendingDeepLinkProvider.notifier).consume();
    expect(container.read(pendingDeepLinkProvider), isNull);
  });

  test('drops links that are not valid', () async {
    source.emit('https://evil.com/track?id=RGdkabupfPI');
    source.emit('liner://track?id=nope');
    await deliver();

    expect(container.read(pendingDeepLinkProvider), isNull);
  });

  test('a later link replaces an unopened earlier one', () async {
    source.emit('liner://track?id=RGdkabupfPI');
    source.emit('liner://album?id=MPREb_xCxkOKReFZv');
    await deliver();

    expect(container.read(pendingDeepLinkProvider)?.type, DeepLinkType.album);
  });

  test('the same link can be opened again after it was consumed', () async {
    final seen = <DeepLinkTarget?>[];
    container.listen(pendingDeepLinkProvider, (_, next) => seen.add(next));

    source.emit('liner://track?id=RGdkabupfPI');
    await deliver();
    container.read(pendingDeepLinkProvider.notifier).consume();
    source.emit('liner://track?id=RGdkabupfPI');
    await deliver();

    expect(seen.whereType<DeepLinkTarget>(), hasLength(2));
  });
}
