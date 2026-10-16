import 'package:flutter_test/flutter_test.dart';
import 'package:liner_mobile/core/utils/formatters.dart';

void main() {
  group('formatBytes', () {
    test('uses the largest sensible unit', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(900), '900 B');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(3 * 1024 * 1024), '3.0 MB');
      expect(formatBytes((1.5 * 1024 * 1024).round()), '1.5 MB');
      expect(formatBytes(2 * 1024 * 1024 * 1024), '2.0 GB');
    });
  });

  group('formatLyricsOffset', () {
    test('shows the sign and the seconds', () {
      expect(formatLyricsOffset(0), '0.0s');
      expect(formatLyricsOffset(300), '+0.3s');
      expect(formatLyricsOffset(-1200), '-1.2s');
    });

    test('adds a decimal for fine adjustments', () {
      expect(formatLyricsOffset(50), '+0.05s');
      expect(formatLyricsOffset(-1250), '-1.25s');
    });
  });

  group('formatDuration', () {
    test('pads the seconds', () {
      expect(formatDuration(const Duration(minutes: 3, seconds: 5)), '3:05');
    });
  });

  group('formatCompactCount', () {
    test('abbreviates thousands and millions', () {
      expect(formatCompactCount(999), '999');
      expect(formatCompactCount(1500), '1.5K');
      expect(formatCompactCount(12300000), '12.3M');
    });
  });
}
