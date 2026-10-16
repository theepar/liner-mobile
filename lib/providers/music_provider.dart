import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/playlist.dart';
import '../core/models/track.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

final popularTracksProvider = FutureProvider<List<Track>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(linerApiProvider).getPopularTracks();
});

final recentlyPlayedProvider = FutureProvider<List<Track>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(linerApiProvider).getRecentlyPlayed();
});

final dailyMixesProvider = FutureProvider<List<Playlist>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(linerApiProvider).getDailyMixes();
});
