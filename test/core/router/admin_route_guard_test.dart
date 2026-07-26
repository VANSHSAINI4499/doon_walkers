// Coverage for the /admin route predicate.
//
// This matters more after Redesign 2.0 Phase 10 than it did before.
// Previously the admin screens lived inside the StatefulShellRoute, and
// AppShell carried a bespoke `ref.listen` that actively navigated a
// demoted admin to Home. Phase 10 moved those screens out to top-level
// routes, which made GoRouter's own `redirect` reliable for them again —
// and made that listener unreachable, so it was removed.
//
// The consequence: this predicate is now the single guard deciding
// whether a demoted admin gets bounced off a screen they are sitting on.
// Both failure directions are user-visible — matching too little leaves
// admin surfaces open to a demoted user, matching too much would bounce
// ordinary members off public pages.

import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isAdminRoute', () {
    test('matches every admin screen reachable from the drawer', () {
      // The drawer's Admin section links to exactly these three.
      expect(isAdminRoute(AppConstants.routeAdminTrekRegistrations), isTrue);
      expect(isAdminRoute(AppConstants.routeAdminMerchInquiries), isTrue);
      expect(isAdminRoute(AppConstants.routeAdminSendNotification), isTrue);
    });

    test('matches the admin screens with no drawer entry', () {
      expect(isAdminRoute(AppConstants.routeAdminRegistrations), isTrue);
      expect(isAdminRoute(AppConstants.routeCommentModeration), isTrue);
      expect(isAdminRoute(AppConstants.routeCommentBlocklist), isTrue);
    });

    test('matches nested detail routes, however deep', () {
      // The relocated Registrations flow pushes two levels deeper. Each
      // pushed location must stay gated, since these are exactly the
      // screens a demoted admin could be sitting several pushes into.
      expect(
        isAdminRoute(AppConstants.adminTrekRegistrationsLocation('trek-1')),
        isTrue,
      );
      expect(
        isAdminRoute(
          AppConstants.adminTrekRegistrationsDetailLocation('trek-1', 'reg-9'),
        ),
        isTrue,
      );
      expect(
        isAdminRoute(AppConstants.adminRegistrationDetailLocation('reg-9')),
        isTrue,
      );
    });

    test('matches the bare /admin prefix', () {
      // No route resolves here any more, but the guard should still treat
      // it as admin territory rather than letting it fall through.
      expect(isAdminRoute(AppConstants.routeAdmin), isTrue);
    });

    test('does NOT match the public tabs', () {
      for (final route in [
        AppConstants.routeHome,
        AppConstants.routeActivity,
        AppConstants.routeTrekLibrary,
        AppConstants.routeChallenges,
        AppConstants.routeProfile,
      ]) {
        expect(isAdminRoute(route), isFalse, reason: '$route must stay open');
      }
    });

    test('does NOT match the public drawer destinations', () {
      for (final route in [
        AppConstants.routeMerchandise,
        AppConstants.routeAbout,
        AppConstants.routeContact,
        AppConstants.routeSupport,
        AppConstants.routeSettings,
      ]) {
        expect(isAdminRoute(route), isFalse, reason: '$route must stay open');
      }
    });

    test('does not match a path that merely starts with the same letters', () {
      // `/administration` shares a prefix with `/admin` but is not under
      // it — a naive startsWith('/admin') without the trailing slash
      // would wrongly gate it.
      expect(isAdminRoute('/administration'), isFalse);
      expect(isAdminRoute('/admin-tools'), isFalse);
    });
  });
}
