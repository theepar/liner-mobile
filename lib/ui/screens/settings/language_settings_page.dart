import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/settings_provider.dart';
import 'settings_widgets.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return SettingsPage(
      title: 'Language',
      description: 'Choose the language used by Liner and system controls.',
      children: [
        const SettingsHeading('Display language'),
        SettingsChoiceCard<AppLocale>(
          value: settings.locale,
          options: [
            for (final locale in AppLocale.values)
              SettingsOption(value: locale, title: locale.label),
          ],
          onChanged: notifier.setLocale,
        ),
      ],
    );
  }
}
