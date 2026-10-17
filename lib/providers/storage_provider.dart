import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio_cache.dart';
import '../services/cover_image_cache.dart';
import 'search_history_provider.dart';

final coverCacheProvider = Provider<DeviceCache>(
  (ref) => const CoverImageCache(),
);

final audioCacheProvider = Provider<DeviceCache>((ref) => const AudioCache());

final storageProvider =
    StateNotifierProvider.autoDispose<StorageController, StorageState>(
      (ref) => StorageController(
        covers: ref.watch(coverCacheProvider),
        audio: ref.watch(audioCacheProvider),
        history: ref.watch(searchHistoryProvider.notifier),
      ),
    );

enum StorageCategory {
  covers('Cover Artwork', 'Album and artist images saved for faster loading'),
  audio('Audio Cache', 'Tracks retained locally for faster replay'),
  searchHistory('Search History', 'Your recent searches on this device');

  const StorageCategory(this.label, this.description);

  final String label;
  final String description;
}

class StorageState {
  const StorageState({
    this.sizes = const {},
    this.isLoading = true,
    this.isClearing = false,
  });

  final Map<StorageCategory, int> sizes;
  final bool isLoading;
  final bool isClearing;

  int bytesOf(StorageCategory category) => sizes[category] ?? 0;

  int get totalBytes => sizes.values.fold(0, (sum, bytes) => sum + bytes);

  int bytesIn(Set<StorageCategory> categories) =>
      categories.fold(0, (sum, category) => sum + bytesOf(category));

  StorageState copyWith({
    Map<StorageCategory, int>? sizes,
    bool? isLoading,
    bool? isClearing,
  }) => StorageState(
    sizes: sizes ?? this.sizes,
    isLoading: isLoading ?? this.isLoading,
    isClearing: isClearing ?? this.isClearing,
  );
}

class StorageController extends StateNotifier<StorageState> {
  StorageController({
    required this._covers,
    required this._audio,
    required this._history,
  }) : super(const StorageState()) {
    unawaited(refresh());
  }

  final DeviceCache _covers;
  final DeviceCache _audio;
  final SearchHistoryNotifier _history;

  Future<void> refresh() async {
    await _history.loaded;
    final covers = await _covers.sizeBytes();
    final audio = await _audio.sizeBytes();
    if (!mounted) return;
    state = StorageState(
      sizes: {
        StorageCategory.covers: covers,
        StorageCategory.audio: audio,
        StorageCategory.searchHistory: _history.storedBytes,
      },
      isLoading: false,
    );
  }

  Future<void> clear(Set<StorageCategory> categories) async {
    if (categories.isEmpty || state.isClearing) return;
    state = state.copyWith(isClearing: true);
    try {
      if (categories.contains(StorageCategory.covers)) await _covers.clear();
      if (categories.contains(StorageCategory.audio)) await _audio.clear();
      if (categories.contains(StorageCategory.searchHistory)) {
        await _history.clear();
      }
    } finally {
      if (mounted) {
        await refresh();
        if (mounted) state = state.copyWith(isClearing: false);
      }
    }
  }
}
