import 'package:doon_walkers/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the route predicate for the Phase QR-2 member-facing check-in
/// scanner — auth-required (any signed-in member), unlike the sibling
/// `_isTrekAdminRoute` predicate (admin-only). Both failure directions
/// matter the same way `trek_admin_route_test.dart` documents: matching
/// too much would gate ordinary trek pages behind sign-in; matching too
/// little would leave the scanner reachable by a guest.
void main() {
  group('isTrekCheckinRoute', () {
    test('matches the check-in scanner for any trek id', () {
      expect(isTrekCheckinRoute('/trek-library/abc-123/check-in'), isTrue);
      expect(
        isTrekCheckinRoute('/trek-library/7f3c1e2a-0b5d-4a8e-9f21-3c5d7e9a1b4f/check-in'),
        isTrue,
      );
    });

    test('does NOT match the public library or a public trek detail page', () {
      expect(isTrekCheckinRoute('/trek-library'), isFalse);
      expect(isTrekCheckinRoute('/trek-library/abc-123'), isFalse);
    });

    test('does NOT match the sibling admin routes', () {
      expect(isTrekCheckinRoute('/trek-library/abc-123/edit'), isFalse);
      expect(isTrekCheckinRoute('/trek-library/abc-123/checkin-qr'), isFalse);
    });

    test('does not match a trek whose id merely equals check-in', () {
      // '/trek-library/check-in' is a *detail* route for a trek with id
      // "check-in" — only a '/check-in' path SEGMENT should count.
      expect(isTrekCheckinRoute('/trek-library/check-in'), isFalse);
    });
  });
}
