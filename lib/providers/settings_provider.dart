import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../core/models/branding_variant.dart';
import '../core/models/connection_report.dart';
import 'api_provider.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ref.watch(apiClientProvider)),
);

const _autoplaySimilarKey = 'liner_autoplay_similar';
const _trackTapActionKey = 'liner_track_tap_action';
const _highQualityKey = 'liner_high_quality_audio';
const _animatedBackgroundKey = 'liner_animated_background';
const _brandingKey = 'liner_branding';

enum TrackTapAction { play, queue }

class SettingsState {
  const SettingsState({
    required this.currentBaseUrl,
    required this.isUsingFallback,
    this.autoplaySimilar = true,
    this.trackTapAction = TrackTapAction.play,
    this.highQualityAudio = false,
    this.animatedBackground = true,
    this.branding = BrandingVariant.standard,
  });

  final String currentBaseUrl;
  final bool isUsingFallback;
  final bool autoplaySimilar;
  final TrackTapAction trackTapAction;
  final bool highQualityAudio;
  final bool animatedBackground;
  final BrandingVariant branding;

  SettingsState copyWith({
    String? currentBaseUrl,
    bool? isUsingFallback,
    bool? autoplaySimilar,
    TrackTapAction? trackTapAction,
    bool? highQualityAudio,
    bool? animatedBackground,
    BrandingVariant? branding,
  }) => SettingsState(
    currentBaseUrl: currentBaseUrl ?? this.currentBaseUrl,
    isUsingFallback: isUsingFallback ?? this.isUsingFallback,
    autoplaySimilar: autoplaySimilar ?? this.autoplaySimilar,
    trackTapAction: trackTapAction ?? this.trackTapAction,
    highQualityAudio: highQualityAudio ?? this.highQualityAudio,
    animatedBackground: animatedBackground ?? this.animatedBackground,
    branding: branding ?? this.branding,
  );
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._client) : super(_snapshot(_client)) {
    unawaited(_loadPreferences());
  }

  final ApiClient _client;

  static SettingsState _snapshot(ApiClient client) => SettingsState(
    currentBaseUrl: client.baseUrl,
    isUsingFallback: client.isUsingFallback,
  );

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = state.copyWith(
      autoplaySimilar: prefs.getBool(_autoplaySimilarKey) ?? true,
      trackTapAction: prefs.getString(_trackTapActionKey) == 'queue'
          ? TrackTapAction.queue
          : TrackTapAction.play,
      highQualityAudio: prefs.getBool(_highQualityKey) ?? false,
      animatedBackground: prefs.getBool(_animatedBackgroundKey) ?? true,
      branding: BrandingVariant.fromId(prefs.getString(_brandingKey)),
    );
  }

  Future<void> setAutoplaySimilar({required bool enabled}) async {
    state = state.copyWith(autoplaySimilar: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoplaySimilarKey, enabled);
  }

  Future<void> setTrackTapAction(TrackTapAction action) async {
    state = state.copyWith(trackTapAction: action);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trackTapActionKey, action.name);
  }

  Future<void> setHighQualityAudio({required bool enabled}) async {
    state = state.copyWith(highQualityAudio: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highQualityKey, enabled);
  }

  Future<void> setAnimatedBackground({required bool enabled}) async {
    state = state.copyWith(animatedBackground: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_animatedBackgroundKey, enabled);
  }

  Future<void> setBranding(BrandingVariant variant) async {
    state = state.copyWith(branding: variant);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_brandingKey, variant.id);
  }

  Future<void> resetPreferences() async {
    state = SettingsState(
      currentBaseUrl: state.currentBaseUrl,
      isUsingFallback: state.isUsingFallback,
    );
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _autoplaySimilarKey,
      _trackTapActionKey,
      _highQualityKey,
      _animatedBackgroundKey,
      _brandingKey,
    ]) {
      await prefs.remove(key);
    }
  }

  Future<void> setBaseUrl(String url) async {
    await _client.setBaseUrl(url);
    state = state.copyWith(
      currentBaseUrl: _client.baseUrl,
      isUsingFallback: _client.isUsingFallback,
    );
  }

  Future<ConnectionReport> checkConnection() => _client.checkConnection();

  Future<void> probeEndpoint() async {
    await _client.probeEndpoint();
    state = state.copyWith(
      currentBaseUrl: _client.baseUrl,
      isUsingFallback: _client.isUsingFallback,
    );
  }
}
