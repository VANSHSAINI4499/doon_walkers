import 'package:doon_walkers/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the route predicate that replaced `/admin/treks/...` when trek
/// admin controls were inlined onto the public Trek Library screen.
///
/// Both failure directions are user-visible:
///   - matching too much (e.g. the plain `/trek-library/:id` detail route)
///     would bounce ordinary members off public trek pages;
///   - matching too little would leave the create/edit forms reachable by
///     a signed-in non-admin, who'd fill in a whole form only for the
///     `treks_insert_admin` / `treks_update_admin` RLS policies to reject
///     the save.
void main() {
  group('isTrekAdminRoute', () {
    test('matches the admin create form', () {
      expect(isTrekAdminRoute('/trek-library/new'), isTrue);
    });

    test('matches the admin edit form for any trek id', () {
      expect(isTrekAdminRoute('/trek-library/abc-123/edit'), isTrue);
      expect(
        isTrekAdminRoute('/trek-library/7f3c1e2a-0b5d-4a8e-9f21-3c5d7e9a1b4f/edit'),
        isTrue,
      );
    });

    test('does NOT match the public library or a public trek detail page', () {
      expect(isTrekAdminRoute('/trek-library'), isFalse);
      expect(isTrekAdminRoute('/trek-library/abc-123'), isFalse);
    });

    test('does NOT match unrelated routes', () {
      expect(isTrekAdminRoute('/'), isFalse);
      expect(isTrekAdminRoute('/gallery'), isFalse);
      expect(isTrekAdminRoute('/profile'), isFalse);
      expect(isTrekAdminRoute('/admin/registrations'), isFalse);
    });

    test('does not match a trek whose id merely ends in the word edit', () {
      // '/trek-library/edit' is a *detail* route for a trek with id
      // "edit" — only a '/edit' path segment should count.
      expect(isTrekAdminRoute('/trek-library/edit'), isFalse);
    });
  });
}
