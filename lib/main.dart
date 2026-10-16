import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/api/api_client.dart';
import 'ui/navigation/main_navigation_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dark immersive status bar and navigation bar styling
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize API client and probe endpoints
  await ApiClient.instance.init();

  runApp(
    const ProviderScope(
      child: LinerApp(),
    ),
  );
}

class LinerApp extends StatelessWidget {
  const LinerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liner',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: LinerTheme.light,
      darkTheme: LinerTheme.dark,
      home: const MainNavigationShell(),
    );
  }
}
