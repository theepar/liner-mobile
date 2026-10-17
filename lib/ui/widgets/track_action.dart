import 'dart:async';

import 'package:flutter/material.dart';

class TrackAction {
  const TrackAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final FutureOr<void> Function() onSelected;
  final bool isDestructive;
}
