import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api/api_client.dart';
import 'core/theme/app_theme.dart';
import 'providers/deep_link_provider.dart';
import 'ui/navigation/auth_gate.dart';

const _startupTimeout = Duration(seconds: 5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Start UI while endpoint probing continues in the background.
  await ApiClient.instance.init().timeout(_startupTimeout, onTimeout: () {});

  runApp(const ProviderScope(child: LinerApp()));
}

class LinerApp extends ConsumerWidget {
  const LinerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(pendingDeepLinkProvider);
    return MaterialApp(
      title: 'Liner',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: LinerTheme.light,
      darkTheme: LinerTheme.dark,
      home: const AuthGate(),
    );
  }
}
