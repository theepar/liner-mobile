import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/detail_scaffold.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DetailScaffold(
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        ...children,
      ],
    ),
  );
}

class SettingsHeading extends StatelessWidget {
  const SettingsHeading(this.title, {super.key, this.description});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, top: 8, bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: 1.1,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    ),
  );
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Material(
      color: LinerColors.darkElevated,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: LinerColors.darkBorderSecondary),
      ),
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0)
              const Divider(height: 1, color: LinerColors.darkBorderPrimary),
            child,
          ],
        ],
      ),
    ),
  );
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    activeThumbColor: Colors.white,
    activeTrackColor: LinerColors.accentPrimary,
    title: Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 14),
    ),
    subtitle: Text(
      description,
      style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
    ),
    value: value,
    onChanged: onChanged,
  );
}

class SettingsOption<T> {
  const SettingsOption({
    required this.value,
    required this.title,
    this.description,
  });

  final T value;
  final String title;
  final String? description;
}

class SettingsChoiceCard<T> extends StatelessWidget {
  const SettingsChoiceCard({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<SettingsOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => RadioGroup<T>(
    groupValue: value,
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
    child: SettingsCard(
      children: [
        for (final option in options)
          RadioListTile<T>(
            value: option.value,
            activeColor: LinerColors.accentPrimary,
            title: Text(
              option.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: option.description == null
                ? null
                : Text(
                    option.description!,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
          ),
      ],
    ),
  );
}

class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.description,
    this.external = false,
  });

  final IconData icon;
  final String title;
  final String? description;
  final VoidCallback onTap;
  final bool external;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: Colors.white70, size: 22),
    title: Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 14),
    ),
    subtitle: description == null
        ? null
        : Text(
            description!,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.35,
            ),
          ),
    trailing: Icon(
      external ? Icons.open_in_new_rounded : Icons.chevron_right_rounded,
      color: Colors.white38,
      size: external ? 18 : 22,
    ),
    onTap: onTap,
  );
}

Future<void> openSettingsPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
