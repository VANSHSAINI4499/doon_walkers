// Pins every known points_ledger reason to human copy, and — the actual
// point of this file — proves an unmapped reason NEVER surfaces the raw
// enum string on screen (the Phase 22 brief's explicit requirement).

import 'package:doon_walkers/features/profile/domain/points_reason_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PointsReasonLabels.labelFor', () {
    test('maps every known reason to non-empty human copy', () {
      for (final reason in [
        'challenge_enrolled',
        'daily_step_goal',
        'trek_checkin',
        'challenge_completed',
      ]) {
        final label = PointsReasonLabels.labelFor(reason);
        expect(label, isNotEmpty);
        expect(label, isNot(reason));
      }
    });

    test(
      'an unmapped reason falls back to a generic label, never the raw enum',
      () {
        final label = PointsReasonLabels.labelFor('some_future_reason_v2');
        expect(label, isNot('some_future_reason_v2'));
        expect(label.contains('_'), isFalse);
      },
    );
  });
}
