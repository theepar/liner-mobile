import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _historyKey = 'liner_search_history';

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>(
      (ref) => SearchHistoryNotifier(),
    );

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super(const []) {
    unawaited(loaded);
  }

  static const maxItems = 30;

  late final Future<void> loaded = _load();

  int get storedBytes =>
      state.fold(0, (total, query) => total + utf8.encode(query).length);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = prefs.getStringList(_historyKey) ?? const [];
  }

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    state = [
      trimmed,
      for (final item in state)
        if (item.toLowerCase() != trimmed.toLowerCase()) item,
    ].take(maxItems).toList();
    await _save();
  }

  Future<void> remove(String query) async {
    state = [
      for (final item in state)
        if (item != query) item,
    ];
    await _save();
  }

  Future<void> clear() async {
    state = const [];
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, state);
  }
}
