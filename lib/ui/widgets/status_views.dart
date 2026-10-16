import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: const Center(
      child: CircularProgressIndicator(color: LinerColors.accentPrimary),
    ),
  );
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        const Icon(
          Icons.cloud_off_rounded,
          color: LinerColors.darkTextTertiary,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: LinerColors.darkTextSecondary,
              fontSize: 13,
            ),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text(
            'Retry',
            style: TextStyle(color: LinerColors.accentSecondary),
          ),
        ),
      ],
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}
