import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import 'main_navigation_shell.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(authProvider.select((user) => user != null));
    return isSignedIn ? const MainNavigationShell() : const LoginScreen();
  }
}
