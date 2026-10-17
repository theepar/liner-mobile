import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/json_helpers.dart';

abstract interface class LyricsOffsetStore {
  Future<int> read(String trackId);

  Future<void> write(String trackId, int offsetMs);
}

class PrefsLyricsOffsetStore implements LyricsOffsetStore {
  const PrefsLyricsOffsetStore();

  static const _key = 'liner_lyrics_offsets';
  static const maxEntries = 200;

  @override
  Future<int> read(String trackId) async => (await _load())[trackId] ?? 0;

  @override
  Future<void> write(String trackId, int offsetMs) async {
    final offsets = await _load()
      ..remove(trackId);
    if (offsetMs != 0) offsets[trackId] = offsetMs;
    while (offsets.length > maxEntries) {
      offsets.remove(offsets.keys.first);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(offsets));
  }

  Future<Map<String, int>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = asMap(jsonDecode(raw)) ?? const {};
      return {
        for (final entry in decoded.entries) entry.key: ?asInt(entry.value),
      };
    } on FormatException {
      return {};
    }
  }
}
