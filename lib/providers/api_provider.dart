import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/liner_api.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

final linerApiProvider = Provider<LinerApi>(
  (ref) => LinerApi(ref.watch(apiClientProvider)),
);
