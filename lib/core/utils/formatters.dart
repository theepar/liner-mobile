String formatDuration(Duration duration) {
  final seconds = duration.inSeconds % 60;
  return '${duration.inMinutes}:${seconds.toString().padLeft(2, '0')}';
}

/// `+0.3s`, `-1.25s` or `0.0s`; two decimals only when finer than 100 ms.
String formatLyricsOffset(int offsetMs) {
  if (offsetMs == 0) return '0.0s';
  final seconds = offsetMs.abs() / 1000;
  final text = offsetMs % 100 == 0
      ? seconds.toStringAsFixed(1)
      : seconds.toStringAsFixed(2);
  return '${offsetMs > 0 ? '+' : '-'}${text}s';
}

/// `0 B`, `512 KB`, `3.4 MB`: one decimal from megabytes up.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String formatCompactCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
