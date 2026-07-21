import 'dart:async';
import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/widgets/app_shell.dart';
import 'package:doon_walkers/features/about/presentation/screens/about_screen.dart';
import 'package:doon_walkers/features/admin/presentation/screens/admin_screen.dart';
import 'package:doon_walkers/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:doon_walkers/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:doon_walkers/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:doon_walkers/features/gallery/presentation/screens/gallery_screen.dart';
import 'package:doon_walkers/features/home/presentation/screens/home_screen.dart';
import 'package:doon_walkers/features/profile/presentation/screens/profile_screen.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/admin_registration_detail_screen.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/admin_registrations_screen.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/admin_trek_form_screen.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/trek_detail_screen.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/trek_library_screen.dart';
import 'package:doon_walkers/features/upcoming_treks/presentation/screens/upcoming_treks_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A [ChangeNotifier] that drives GoRouter's [refreshListenable].
///
/// Notifies on two independent signals:
///   1. Supabase's raw `onAuthStateChange` — sign-in, sign-out, token refresh.
///   2. [currentUserProvider] — the `public.users` row for the signed-in user.
///      This is what lets a *late-arriving* role (the row loading a moment
///      after sign-in) re-trigger the redirect logic, instead of only
///      re-evaluating on the initial auth event. Without this, an admin who
///      hits `/admin` before their row has loaded once would get redirected
///      to Home by the loading-guard in [redirect] and then never get
///      re-checked, since raw auth events don't fire again just because a
///      Riverpod stream resolved.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange
        .asBroadcastStream()
        .listen((_) => notifyListeners());

    ref.listen(currentUserProvider, (previous, next) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

/// True for `/admin` itself and any nested route under it (currently
/// `/admin/registrations`).
/// Centralised here so the redirect guard can't gate the exact `/admin`
/// path while missing a nested one added later.
///
/// Note this no longer covers trek editing: that moved under
/// `/trek-library/...` when admin controls were inlined onto the public
/// screens. Those paths are matched by [_isTrekAdminRoute] instead and
/// gated by the same admin check below.
bool _isAdminRoute(String location) =>
    location == AppConstants.routeAdmin || location.startsWith('${AppConstants.routeAdmin}/');

/// True for the admin-only trek create/edit forms that now live under the
/// public `/trek-library` branch — `/trek-library/new` and
/// `/trek-library/:id/edit`.
///
/// Without this, inlining the admin controls would have quietly widened
/// access: the forms used to sit behind `/admin/treks/...` and were
/// covered by [_isAdminRoute], so a non-admin deep-linking to them got
/// bounced. RLS (`treks_insert_admin` / `treks_update_admin`) always
/// rejected the actual write either way, but showing a stranger a
/// working-looking trek form that fails only on save is bad UX — this
/// keeps the pre-restructure behaviour of redirecting instead.
/// Exposed for test: the matching is easy to get subtly wrong (matching
/// the plain detail route would lock members out of trek pages entirely;
/// failing to match `/edit` would leave the form open to them), and there
/// is no deep-link scheme registered on Android to exercise it at runtime.
@visibleForTesting
bool isTrekAdminRoute(String location) => _isTrekAdminRoute(location);

bool _isTrekAdminRoute(String location) {
  if (location == AppConstants.routeTrekNew) return true;

  // Match the exact `/trek-library/{id}/edit` shape by segment count
  // rather than a suffix check: a plain `endsWith('/edit')` would also
  // match `/trek-library/edit`, which is really the *detail* route for a
  // trek whose id happens to be "edit".
  final segments = Uri.parse(location).pathSegments;
  return segments.length == 3 &&
      '/${segments.first}' == AppConstants.routeTrekLibrary &&
      segments.last == 'edit';
}

/// Exposes the [GoRouter] instance as a Riverpod provider (rather than a
/// bare top-level field) so its `redirect` logic can [Ref.read] Riverpod
/// state directly and its refresh listenable can [Ref.listen] to it — see
/// [_RouterRefreshNotifier].
final routerProvider = Provider<GoRouter>(
  (ref) {
    final refreshNotifier = _RouterRefreshNotifier(ref);
    ref.onDispose(refreshNotifier.dispose);

    return _buildRouter(ref, refreshNotifier);
  },
  name: 'routerProvider',
);

/// DoonWalkers application router.
///
/// Uses [GoRouter] with a [StatefulShellRoute] so that:
///   - The 5 primary tabs each maintain their own navigation stack.
///   - The [AppShell] (bottom nav + drawer) persists across route transitions.
///   - Profile and Admin routes live inside the shell (drawer keeps visible)
///     but as standalone branches not surfaced in the bottom nav.
///   - Auth routes (/sign-in, /sign-up, /forgot-password) are top-level outside
///     the shell so bottom navigation bars are suppressed.
GoRouter _buildRouter(Ref ref, _RouterRefreshNotifier refreshNotifier) => GoRouter(
  initialLocation: AppConstants.routeHome,
  debugLogDiagnostics: kDebugMode,
  refreshListenable: refreshNotifier,
  routes: [
    // Top-Level Auth Routes (Outside AppShell)
    GoRoute(
      path: AppConstants.routeSignIn,
      name: 'sign-in',
      builder: (context, state) => SignInScreen(
        redirectTo: state.uri.queryParameters['redirectTo'],
      ),
    ),
    GoRoute(
      path: AppConstants.routeSignUp,
      name: 'sign-up',
      builder: (context, state) => SignUpScreen(
        redirectTo: state.uri.queryParameters['redirectTo'],
      ),
    ),
    GoRoute(
      path: AppConstants.routeForgotPassword,
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // StatefulShellRoute for App Navigation Tabs & Drawer Screens
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        // Branch 0 — Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeHome,
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),

        // Branch 1 — Trek Library
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeTrekLibrary,
              name: 'trek-library',
              builder: (context, state) => const TrekLibraryScreen(),
              routes: [
                // /trek-library/new — admin trek create form. Declared
                // BEFORE ':id' on purpose: GoRouter matches in order, so
                // without this ordering "new" would be captured as a trek
                // id and routed to the detail screen instead.
                GoRoute(
                  path: 'new',
                  name: 'trek-new',
                  builder: (context, state) => const AdminTrekFormScreen(),
                ),
                // /trek-library/:id — trek detail, public (RLS gates
                // draft visibility server-side; see TrekDetailScreen).
                GoRoute(
                  path: ':id',
                  name: 'trek-detail',
                  builder: (context, state) => TrekDetailScreen(
                    trekId: state.pathParameters['id']!,
                    // Set by TrekRegisterButton's sign-in return path so a
                    // guest who signed in mid-registration lands back in
                    // the form rather than just on the trek page.
                    openRegistration: state.uri.queryParameters['register'] == '1',
                  ),
                  routes: [
                    // /trek-library/:id/edit — admin trek edit form.
                    // Lives under the public branch (not /admin/treks)
                    // now that admin controls render inline on the
                    // public screens; treks_update_admin RLS is the
                    // real gate either way.
                    GoRoute(
                      path: 'edit',
                      name: 'trek-edit',
                      builder: (context, state) => AdminTrekFormScreen(
                        trekId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Branch 2 — Gallery
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeGallery,
              name: 'gallery',
              builder: (context, state) => const GalleryScreen(),
            ),
          ],
        ),

        // Branch 3 — Upcoming Treks
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeUpcomingTreks,
              name: 'upcoming-treks',
              builder: (context, state) => const UpcomingTreksScreen(),
            ),
          ],
        ),

        // Branch 4 — About
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeAbout,
              name: 'about',
              builder: (context, state) => const AboutScreen(),
            ),
          ],
        ),

        // Branch 5 — Profile (secondary, drawer)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeProfile,
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),

        // Branch 6 — Admin (secondary, drawer)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeAdmin,
              name: 'admin',
              builder: (context, state) => const AdminScreen(),
              routes: [
                // /admin/registrations — the one admin surface that stays
                // its own destination. Trek and gallery CRUD used to live
                // here too (/admin/treks, /admin/gallery); those moved
                // inline onto the public Trek Library and Gallery screens,
                // since each has an obvious public screen to embed into.
                // A cross-trek roster doesn't, so it stays here.
                //
                // Admin-gated by the same route-prefix check the /admin
                // redirect already does; see _isAdminRoute below.
                GoRoute(
                  path: 'registrations',
                  name: 'admin-registrations',
                  builder: (context, state) => const AdminRegistrationsScreen(),
                  routes: [
                    // /admin/registrations/:id — full detail incl. the
                    // sensitive registrant fields and the admin-only
                    // payment_status control. Nested here so it inherits
                    // the /admin prefix gate rather than needing its own.
                    GoRoute(
                      path: ':id',
                      name: 'admin-registration-detail',
                      builder: (context, state) => AdminRegistrationDetailScreen(
                        registrationId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],

  // Auth Guard & Redirect Hook
  redirect: (context, state) {
    final supabase = Supabase.instance.client;
    final sessionUser = supabase.auth.currentUser;
    final location = state.uri.path;

    // Check if target is an auth screen
    final isAuthScreen = location == AppConstants.routeSignIn ||
        location == AppConstants.routeSignUp ||
        location == AppConstants.routeForgotPassword;

    // 1. If user is signed in and trying to visit an auth screen, redirect to destination or home
    if (sessionUser != null && isAuthScreen) {
      return state.uri.queryParameters['redirectTo'] ?? AppConstants.routeHome;
    }

    // 2. If user is guest and trying to visit protected routes (/profile,
    //    /admin + nested, or the inlined trek admin forms), redirect to
    //    Sign In.
    final isProtectedRoute = location == AppConstants.routeProfile ||
        _isAdminRoute(location) ||
        _isTrekAdminRoute(location);
    if (sessionUser == null && isProtectedRoute) {
      return '${AppConstants.routeSignIn}?redirectTo=${Uri.encodeComponent(state.uri.toString())}';
    }

    // 3. If user is signed in and trying to visit /admin (or any nested
    //    /admin/... route), or one of the trek admin forms now living
    //    under /trek-library, verify admin role. Checking the exact path
    //    alone would only gate /admin itself — a non-admin could still
    //    deep-link straight to /admin/registrations or
    //    /trek-library/new otherwise, even though the UI never offers
    //    those to them.
    if (sessionUser != null && (_isAdminRoute(location) || _isTrekAdminRoute(location))) {
      final userAsync = ref.read(currentUserProvider);

      // The public.users row hasn't resolved into a value yet — either
      // still loading (e.g. immediately after sign-in) or a transient
      // RealtimeSubscribeException from a WebSocket reconnect landed
      // before any data ever arrived (rare, but possible on a flaky
      // first connection). Don't gate on isAdminProvider while there's
      // no confirmed value either way, that would silently and
      // permanently bounce a real admin to Home. Let the navigation
      // through for now; _RouterRefreshNotifier re-runs this check the
      // moment currentUserProvider actually resolves.
      if (!userAsync.hasValue) {
        return null;
      }

      final isAdmin = ref.read(isAdminProvider);
      if (!isAdmin) {
        // Non-admin registered user hitting /admin -> silently bounced to Home per AGENTS.md rules
        return AppConstants.routeHome;
      }
    }

    return null; // no redirect
  },

  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);
