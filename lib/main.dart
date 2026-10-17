import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api/api_client.dart';
import 'core/theme/app_theme.dart';
import 'providers/deep_link_provider.dart';
import 'providers/player_provider.dart';
import 'providers/settings_provider.dart';
import 'services/audio_engine.dart';
import 'services/background_audio_engine.dart';
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

  final audioEngine = await _createAudioEngine();
  runApp(
    ProviderScope(
      overrides: [audioEngineProvider.overrideWithValue(audioEngine)],
      child: const LinerApp(),
    ),
  );
}

Future<AudioEngine> _createAudioEngine() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return JustAudioEngine();
  }
  try {
    return await BackgroundAudioEngine.create();
  } on Exception catch (error) {
    debugPrint('Background audio unavailable: $error');
    return JustAudioEngine();
  }
}

class LinerApp extends ConsumerWidget {
  const LinerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(pendingDeepLinkProvider);
    final locale = ref.watch(settingsProvider.select((state) => state.locale));
    return MaterialApp(
      title: 'Liner',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: LinerTheme.light,
      darkTheme: LinerTheme.dark,
      locale: locale.locale,
      supportedLocales: const [Locale('en'), Locale('ru'), Locale('uk')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
    );
  }
}
