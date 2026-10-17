import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/providers/search_history_provider.dart';
import 'package:liner_mobile/providers/storage_provider.dart';
import 'package:liner_mobile/services/cover_image_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCache implements DeviceCache {
  _FakeCache(this.bytes);

  int bytes;
  int clears = 0;

  @override
  Future<int> sizeBytes() async => bytes;

  @override
  Future<void> clear() async {
    clears++;
    bytes = 0;
  }
}

void main() {
  late _FakeCache covers;
  late _FakeCache audio;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'liner_search_history': ['abc', 'de'],
    });
    covers = _FakeCache(4096);
    audio = _FakeCache(2048);
    container = ProviderContainer(
      overrides: [
        coverCacheProvider.overrideWithValue(covers),
        audioCacheProvider.overrideWithValue(audio),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<StorageState> measured() async {
    final subscription = container.listen(storageProvider, (_, _) {});
    addTearDown(subscription.close);
    while (container.read(storageProvider).isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(storageProvider);
  }

  test('measures each category and the total', () async {
    final state = await measured();

    expect(state.bytesOf(StorageCategory.covers), 4096);
    expect(state.bytesOf(StorageCategory.audio), 2048);
    expect(state.bytesOf(StorageCategory.searchHistory), 5);
    expect(state.totalBytes, 6149);
  });

  test('clears only the chosen categories', () async {
    await measured();
    final controller = container.read(storageProvider.notifier);

    await controller.clear({StorageCategory.covers});
    final state = container.read(storageProvider);

    expect(covers.clears, 1);
    expect(audio.clears, 0);
    expect(state.bytesOf(StorageCategory.covers), 0);
    expect(state.bytesOf(StorageCategory.audio), 2048);
    expect(state.bytesOf(StorageCategory.searchHistory), 5);
    expect(state.isClearing, isFalse);
  });

  test('clearing search history empties it everywhere', () async {
    await measured();

    await container.read(storageProvider.notifier).clear({
      StorageCategory.searchHistory,
    });

    expect(covers.clears, 0);
    expect(audio.clears, 0);
    expect(container.read(searchHistoryProvider), isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        'liner_search_history',
      ),
      isEmpty,
    );
    expect(
      container.read(storageProvider).bytesOf(StorageCategory.searchHistory),
      0,
    );
  });

  test('clearing nothing does nothing', () async {
    await measured();

    await container.read(storageProvider.notifier).clear({});

    expect(covers.clears, 0);
  });
}
