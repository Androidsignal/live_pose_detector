import 'package:flutter_test/flutter_test.dart';
import 'package:live_pose_detector/live_pose_detector.dart';

void main() {
  group('signedLineDeviation', () {
    test('zero when point sits exactly on the line', () {
      final deviation = signedLineDeviation(
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(50, 0),
      );
      expect(deviation, 0);
    });

    test('sign flips depending on which side of the line the point is on', () {
      final below = signedLineDeviation(
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(50, 20),
      );
      final above = signedLineDeviation(
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(50, -20),
      );
      expect(below, greaterThan(0));
      expect(above, lessThan(0));
      expect(below, -above);
    });

    test('normalized by line length — same fractional offset, same deviation', () {
      final shortLine = signedLineDeviation(
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(50, 10), // 10% of line length off
      );
      final longLine = signedLineDeviation(
        const Offset(0, 0),
        const Offset(1000, 0),
        const Offset(500, 100), // also 10% of line length off
      );
      expect(shortLine, closeTo(longLine, 1e-9));
    });

    test('degenerate (zero-length) line returns 0 instead of dividing by zero', () {
      final deviation = signedLineDeviation(
        const Offset(10, 10),
        const Offset(10, 10),
        const Offset(50, 50),
      );
      expect(deviation, 0);
    });
  });
}
