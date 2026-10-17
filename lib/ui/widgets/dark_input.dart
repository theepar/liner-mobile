import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

InputDecoration darkInputDecoration({
  String? hint,
  String? label,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffix,
  String? counterText,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );

  return InputDecoration(
    hintText: hint,
    labelText: label,
    errorText: errorText,
    counterText: counterText,
    hintStyle: const TextStyle(color: Colors.white38),
    labelStyle: const TextStyle(color: Colors.white60),
    prefixIcon: prefixIcon,
    suffixIcon: suffix,
    filled: true,
    fillColor: LinerColors.darkElevated,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(LinerColors.darkBorderSecondary),
    enabledBorder: border(LinerColors.darkBorderSecondary),
    focusedBorder: border(LinerColors.accentPrimary),
    errorBorder: border(Colors.redAccent),
    focusedErrorBorder: border(Colors.redAccent),
  );
}

class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: entry.key == selected
                        ? LinerColors.darkPanel
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: entry.key == selected
                          ? Colors.white
                          : Colors.white60,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
