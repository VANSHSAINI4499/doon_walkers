// Consecutive-confirmation arrival logic — the spec's "avoid false
// positives" requirement lives entirely here, so the cases that matter
// are jitter (a single stray close reading shouldn't trigger arrival)
// and recovery (moving back outside the threshold resets the streak).

import 'package:doon_walkers/features/trip_tracking/domain/services/arrival_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArrivalDetector', () {
    test('does not report arrival before the confirmation count is reached', () {
      final detector = ArrivalDetector(thresholdMeters: 50, requiredConfirmations: 3);
      expect(detector.recordReading(10), isFalse);
      expect(detector.recordReading(20), isFalse);
    });

    test('reports arrival on the Nth consecutive within-threshold reading', () {
      final detector = ArrivalDetector(thresholdMeters: 50, requiredConfirmations: 3);
      expect(detector.recordReading(40), isFalse);
      expect(detector.recordReading(30), isFalse);
      expect(detector.recordReading(10), isTrue);
    });

    test('a single reading outside the threshold does not trigger arrival', () {
      final detector = ArrivalDetector(thresholdMeters: 50);
      expect(detector.recordReading(20), isFalse);
      expect(detector.recordReading(200), isFalse);
    });

    test('a reading falling back outside the threshold resets the streak', () {
      final detector = ArrivalDetector(thresholdMeters: 50, requiredConfirmations: 3);
      expect(detector.recordReading(10), isFalse);
      expect(detector.recordReading(10), isFalse);
      // Jitter — briefly outside threshold, resets progress.
      expect(detector.recordReading(60), isFalse);
      expect(detector.recordReading(10), isFalse);
      expect(detector.recordReading(10), isFalse);
      expect(detector.recordReading(10), isTrue);
    });

    test('exactly-at-threshold counts as within threshold', () {
      final detector = ArrivalDetector(thresholdMeters: 50, requiredConfirmations: 1);
      expect(detector.recordReading(50), isTrue);
    });

    test('reset clears the streak', () {
      final detector = ArrivalDetector(thresholdMeters: 50, requiredConfirmations: 2);
      expect(detector.recordReading(10), isFalse);
      detector.reset();
      expect(detector.recordReading(10), isFalse);
      expect(detector.recordReading(10), isTrue);
    });
  });
}
