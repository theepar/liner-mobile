String formatDuration(Duration duration) {
  final seconds = duration.inSeconds % 60;
  return '${duration.inMinutes}:${seconds.toString().padLeft(2, '0')}';
}

String formatCompactCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
