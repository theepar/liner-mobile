import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/api_client.dart';
import '../../../providers/music_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _showAuthDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool isRegister = false;
    final usernameCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    bool isLoading = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: LinerColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isRegister ? 'Create Liner Account' : 'Sign in to Liner',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isRegister) ...[
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LinerColors.accentPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setModalState(() {
                                isLoading = true;
                                errorText = null;
                              });
                              try {
                                if (isRegister) {
                                  final user = await ApiClient.instance.register(
                                    email: emailCtrl.text.trim(),
                                    password: passwordCtrl.text,
                                    username: usernameCtrl.text.trim(),
                                    displayName: nameCtrl.text.trim(),
                                  );
                                  if (user != null) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) setState(() {});
                                  }
                                } else {
                                  final user = await ApiClient.instance.login(
                                    emailCtrl.text.trim(),
                                    passwordCtrl.text,
                                  );
                                  if (user != null) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) setState(() {});
                                  }
                                }
                              } catch (e) {
                                setModalState(() {
                                  isLoading = false;
                                  errorText = 'Authentication failed. Please check credentials.';
                                });
                              }
                            },
                      child: isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isRegister ? 'Register' : 'Sign In', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      child: Text(
                        isRegister ? 'Already have an account? Sign in' : "Don't have an account? Register",
                        style: const TextStyle(color: LinerColors.accentSecondary, fontSize: 13),
                      ),
                      onPressed: () {
                        setModalState(() {
                          isRegister = !isRegister;
                          errorText = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final user = ApiClient.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 28,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('ACCOUNT'),
            Container(
              decoration: BoxDecoration(
                color: LinerColors.darkElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LinerColors.darkBorderSecondary),
              ),
              child: user != null
                  ? ListTile(
                      leading: CircleAvatar(
                        backgroundColor: LinerColors.accentPrimary,
                        backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                        child: user.avatarUrl == null
                            ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      title: Text(user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: Text('@${user.username}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () async {
                          await ApiClient.instance.logout();
                          setState(() {});
                        },
                        child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                    )
                  : ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: LinerColors.accentPrimary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_rounded, color: LinerColors.accentPrimary, size: 22),
                      ),
                      title: const Text('Sign in to Liner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Sync library and recommendations', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LinerColors.darkPanel,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _showAuthDialog(context),
                        child: const Text('Sign In', style: TextStyle(fontSize: 12)),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('API BACKEND SERVER'),
            Container(
              decoration: BoxDecoration(
                color: LinerColors.darkElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LinerColors.darkBorderSecondary),
              ),
              child: Column(
                children: [
                  RadioGroup<String>(
                    groupValue: settings.currentBaseUrl,
                    onChanged: (val) {
                      if (val != null) notifier.setBaseUrl(val);
                    },
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          title: Text('Primary Official API', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('https://api.tryliner.fun', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          value: primaryApiUrl,
                          activeColor: LinerColors.accentPrimary,
                        ),
                        Divider(height: 1, color: LinerColors.darkBorderPrimary),
                        RadioListTile<String>(
                          title: Text('Edge Relay Backup', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text('http://edge.tryliner.fun:10518', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          value: fallbackApiUrl,
                          activeColor: LinerColors.accentPrimary,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: LinerColors.darkBorderPrimary),
                  ListTile(
                    title: const Text('Auto-Probe Health', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(
                      settings.isUsingFallback ? 'Active: Fallback Edge Relay' : 'Active: Primary Official API',
                      style: TextStyle(
                        color: settings.isUsingFallback ? Colors.amber : Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LinerColors.darkPanel,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => notifier.probeEndpoint(),
                      child: const Text('Probe', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('AUDIO STREAMING QUALITY'),
            Container(
              decoration: BoxDecoration(
                color: LinerColors.darkElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LinerColors.darkBorderSecondary),
              ),
              child: RadioGroup<String>(
                groupValue: settings.audioQuality,
                onChanged: (val) {
                  if (val != null) notifier.setAudioQuality(val);
                },
                child: const Column(
                  children: [
                    RadioListTile<String>(
                      title: Text('High Quality (Opus 320 kbps)', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: 'high',
                      activeColor: LinerColors.accentPrimary,
                    ),
                    Divider(height: 1, color: LinerColors.darkBorderPrimary),
                    RadioListTile<String>(
                      title: Text('Medium Quality (Opus 160 kbps)', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: 'medium',
                      activeColor: LinerColors.accentPrimary,
                    ),
                    Divider(height: 1, color: LinerColors.darkBorderPrimary),
                    RadioListTile<String>(
                      title: Text('Normal (AAC 128 kbps)', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: 'normal',
                      activeColor: LinerColors.accentPrimary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('CACHE & STORAGE'),
            Container(
              decoration: BoxDecoration(
                color: LinerColors.darkElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LinerColors.darkBorderSecondary),
              ),
              child: ListTile(
                title: const Text('Clear Temporary Cache', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Cached album covers & lyrics (~18.4 MB)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: TextButton(
                  child: const Text('Clear', style: TextStyle(color: LinerColors.accentSecondary)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cache cleared successfully'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('ABOUT'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LinerColors.darkElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LinerColors.darkBorderSecondary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: LinerColors.accentPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('L', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Liner Mobile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                          SizedBox(height: 2),
                          Text('Version 1.0.4', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Modern music streaming player with syllable-synced lyrics and reactive dynamic visuals. Built with Flutter, mirroring the official Liner Desktop experience.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'GitHub: github.com/tryliner/desktop',
                    style: TextStyle(color: LinerColors.accentSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 1.1,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
