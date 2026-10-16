import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mini_player.dart';
import 'status_views.dart';

/// Frame for pages opened from the main tabs; keeps the mini player in reach.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({super.key, required this.body, this.actions});

  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

/// Loading, error and content states for a page backed by a single request.
Widget detailBody<T>(
  AsyncValue<T> value, {
  required String errorMessage,
  required VoidCallback onRetry,
  required Widget Function(T data) builder,
}) => value.when(
  loading: () => const LoadingView(height: 320),
  error: (_, _) => Padding(
    padding: const EdgeInsets.only(top: 80),
    child: ErrorRetry(message: errorMessage, onRetry: onRetry),
  ),
  data: builder,
);
