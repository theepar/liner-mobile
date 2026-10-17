import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/models/liner_user.dart';
import 'api_provider.dart';

final authProvider = StateNotifierProvider<AuthNotifier, LinerUser?>(
  (ref) => AuthNotifier(ref.watch(apiClientProvider)),
);

final userIdProvider = Provider<String?>(
  (ref) => ref.watch(authProvider.select((user) => user?.id)),
);

class AuthNotifier extends StateNotifier<LinerUser?> {
  AuthNotifier(this._client) : super(_client.currentUser) {
    _subscription = _client.userChanges.listen((user) => state = user);
  }

  final ApiClient _client;
  late final StreamSubscription<LinerUser?> _subscription;

  Future<void> signIn(String email, String password) async {
    state = await _client.login(email, password);
  }

  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    state = await _client.register(
      email: email,
      password: password,
      username: username,
      displayName: displayName,
    );
  }

  Future<void> signOut() => _client.logout();

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
