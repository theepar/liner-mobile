import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import 'api_provider.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ref.watch(apiClientProvider)),
);

class SettingsState {
  const SettingsState({
    required this.currentBaseUrl,
    required this.isUsingFallback,
  });

  final String currentBaseUrl;
  final bool isUsingFallback;
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._client) : super(_snapshot(_client));

  final ApiClient _client;

  static SettingsState _snapshot(ApiClient client) => SettingsState(
    currentBaseUrl: client.baseUrl,
    isUsingFallback: client.isUsingFallback,
  );

  Future<void> setBaseUrl(String url) async {
    await _client.setBaseUrl(url);
    state = _snapshot(_client);
  }

  Future<void> probeEndpoint() async {
    await _client.probeEndpoint();
    state = _snapshot(_client);
  }
}
