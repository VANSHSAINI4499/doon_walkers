import 'dart:async';
import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/widgets/app_shell.dart';
import 'package:doon_walkers/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:doon_walkers/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:doon_walkers/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:doon_walkers/features/comments/presentation/screens/admin_blocklist_screen.dart';
import 'package:doon_walkers/features/comments/presentation/screens/comment_moderation_screen.dart';
import 'package:doon_walkers/features/home/presentation/screens/home_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/admin_merch_inquiries_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/admin_product_form_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/merchandise_catalog_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/product_detail_screen.dart';
import 'package:doon_walkers/features/notifications/presentation/screens/admin_send_notification_screen.dart';
import 'package:doon_walkers/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:doon_walkers/features/profile/presentation/screens/profile_screen.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/admin_registration_detail_screen.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/admin_registrations_screen.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/admin_trek_picker_screen.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/admin_trek_registrations_screen.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/admin_trek_form_screen.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/trek_detail_screen.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/trek_library_screen.dart';
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

/// True for the admin-only merchandise create/edit forms
/// (`/merchandise/new` and `/merchandise/:id/edit`) — mirrors
/// [_isTrekAdminRoute] exactly. The catalog and detail routes
/// themselves are public (browsing merch needs no admin check); only
/// these two mutate data, so only these two need gating here on top of
/// RLS.
bool _isMerchAdminRoute(String location) {
  if (location == AppConstants.routeMerchandiseNew) return true;

  final segments = Uri.parse(location).pathSegments;
  return segments.length == 3 &&
      '/${segments.first}' == AppConstants.routeMerchandise &&
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
///   - Every primary tab maintains its own navigation stack.
///   - The [AppShell] (bottom nav + drawer) persists across route transitions.
///   - Trek Registrations IS a bottom tab, but only for an admin — see
///     AppShell's doc for how it handles that role-dependent tab count
///     without an invalid `selectedIndex`.
///   - Auth routes (/sign-in, /sign-up, /forgot-password) are top-level outside
///     the shell so bottom navigation bars are suppressed.
///   - /notifications and /merchandise (Version 2, Phase M1) are ALSO
///     top-level, outside the shell — both are reached from an
///     AppBar/Drawer affordance visible on every branch (the bell
///     icon, the drawer's Merchandise entry), so nesting either under
///     one specific branch would silently switch tabs depending on
///     which was current when opened. See each route constant's own
///     doc for the full reasoning.
///
/// Branch layout (branch index — must match [AppShell]'s destinations
/// order for the ones that ARE tabs):
///   0: Home                        1: Trek Library
///   2: Profile (tab)               3: Trek Registrations (admin-only tab)
///   4: Admin-only standalone screens (drawer/dashboard-only, no index
///      screen of their own — see branch 4's own doc)
///
/// About and Upcoming Treks were removed in Part B — About's content
/// moved into Home, Upcoming Treks (a placeholder with no real content)
/// was dropped rather than replaced. Gallery was removed later still —
/// the standalone cross-trek tab is gone for every role; gallery
/// MANAGEMENT stays exactly where it was, inline on each Trek Detail
/// page's TrekGallerySection.
///
/// The Admin Dashboard (`/admin` itself, a static "access verified"
/// banner with a module-card grid) was removed once every card either
/// had an inline/tab equivalent elsewhere or — Send Notification — moved
/// onto Profile (admin-only, gated on [isAdminProvider]). Its three
/// surviving admin-only screens (Registrations, Comment Moderation,
/// Send Notification) no longer share a `/admin` parent route in the
/// tree; each is its own standalone top-level route in branch 4 below,
/// still under an `/admin/...` path so [_isAdminRoute]'s prefix check
/// keeps gating them exactly as before. There is deliberately no route
/// left for bare `/admin` — nothing in the UI links there anymore.
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
    // /notifications — deliberately top-level, not nested under any
    // StatefulShellRoute branch. See AppConstants.routeNotifications'
    // doc for why: the bell icon that opens it lives in AppShell's
    // AppBar, visible from every branch, and a notification tap can
    // fire from ANY app state — nesting it under one specific branch
    // would silently switch tabs when opened from a different one
    // (push() resolves to whichever branch a route structurally
    // belongs to). Protected like /profile — see the redirect guard.
    GoRoute(
      path: AppConstants.routeNotifications,
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    // /merchandise — deliberately top-level, same reasoning as
    // /notifications above: reached from the Navigation Drawer, which
    // is visible from every branch, so nesting this under any ONE of
    // them would silently switch tabs depending on which was current
    // when the drawer opened. Publicly browsable — no redirect guard
    // here, only the nested new/edit admin forms are gated (see
    // `_isMerchAdminRoute` below).
    GoRoute(
      path: AppConstants.routeMerchandise,
      name: 'merchandise',
      builder: (context, state) => const MerchandiseCatalogScreen(),
      routes: [
        // /merchandise/new — declared BEFORE ':id', same reasoning as
        // /trek-library/new: GoRouter matches in order, so without this
        // ordering "new" would be captured as a product id instead.
        GoRoute(
          path: 'new',
          name: 'merchandise-new',
          builder: (context, state) => const AdminProductFormScreen(),
        ),
        GoRoute(
          path: ':id',
          name: 'merchandise-detail',
          builder: (context, state) => ProductDetailScreen(
            productId: state.pathParameters['id']!,
            // Set by ProductBuyButton's sign-in return path so a guest
            // who signed in mid-inquiry lands back in the form rather
            // than just on the product page — mirrors
            // TrekRegisterButton's `register=1` round trip.
            openBuyForm: state.uri.queryParameters['buy'] == '1',
            // Set by WishlistButton's sign-in return path — same idea,
            // completes the original add-to-wishlist tap automatically.
            openWishlist: state.uri.queryParameters['wishlist'] == '1',
          ),
          routes: [
            GoRoute(
              path: 'edit',
              name: 'merchandise-edit',
              builder: (context, state) => AdminProductFormScreen(
                productId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
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
                    // Set by CommentThread's "Sign in to comment" sign-in
                    // return path — same idea, for the comment input.
                    openComment: state.uri.queryParameters['comment'] == '1',
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

        // Branch 2 — Profile (now a bottom-nav tab; previously drawer-only)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeProfile,
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),

        // Branch 3 — Trek Registrations (admin-only bottom-nav TAB).
        //
        // A standalone top-level branch — NOT nested under the Admin
        // Dashboard branch below — precisely because StatefulShellRoute
        // branches are what NavigationBar/goBranch(index) operate on;
        // a route nested inside another branch's GoRoute tree can't be
        // separately tab-selected. Path still starts with /admin/... so
        // _isAdminRoute's prefix check gates it exactly like every other
        // admin surface — a non-admin (or one demoted while sitting on
        // this tab) gets redirected by the same guard, no special case
        // needed here for that.
        //
        // AppShell only shows this as a 4th destination when
        // isAdminProvider is true (see its dynamic destinations list) —
        // the branch itself always exists in the tree for every role, the
        // *bottom-tab visibility* of it is what's role-conditional.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeAdminTrekRegistrations,
              name: 'admin-trek-registrations',
              builder: (context, state) => const AdminTrekPickerScreen(),
              routes: [
                GoRoute(
                  path: ':trekId',
                  name: 'admin-trek-registrations-detail',
                  builder: (context, state) => AdminTrekRegistrationsScreen(
                    trekId: state.pathParameters['trekId']!,
                  ),
                  routes: [
                    // /admin/trek-registrations/:trekId/:id — the SAME
                    // AdminRegistrationDetailScreen the flat roster
                    // (branch 4) also opens, reached via a path nested in
                    // THIS branch rather than reusing
                    // adminRegistrationDetailLocation. go_router resolves
                    // a route's navigator structurally from where it sits
                    // in the tree, not from whichever branch happens to
                    // be visible when push() is called — pushing the
                    // branch-4 path from here would silently switch the
                    // shell to branch 4 and append onto ITS stack, so
                    // "back" would land on the Admin Dashboard instead of
                    // this trek's roster. Nesting it here keeps the push
                    // (and its back button) inside this tab's own stack.
                    GoRoute(
                      path: ':id',
                      name: 'admin-trek-registrations-registration-detail',
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

        // Branch 4 — admin-only standalone screens, no shared parent
        // route or index screen (the old `/admin` Admin Dashboard was
        // removed — see this file's top doc). Each is its own full-path
        // top-level route rather than nested under a common `/admin`
        // GoRoute, since there's no longer a shared screen for them to
        // nest under; `/admin/...` is still the literal path string on
        // each one purely so [_isAdminRoute]'s prefix check keeps gating
        // them without needing a matching change.
        StatefulShellBranch(
          routes: [
            // /admin/registrations — the flat cross-trek roster. Trek and
            // gallery CRUD used to live under /admin too (/admin/treks,
            // /admin/gallery); those moved inline onto the public Trek
            // Library screen (and TrekGallerySection on Trek Detail for
            // gallery), since each has an obvious public screen to embed
            // into. A cross-trek roster doesn't, so it stays a standalone
            // admin-only screen — no other entry point in the app links
            // to it, only reachable by direct navigation (there is none
            // wired up in the UI right now).
            GoRoute(
              path: AppConstants.routeAdminRegistrations,
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
            // /admin/comments — cross-trek hidden-comments moderation
            // queue (Phase 7). No UI entry point currently links here
            // either — inline hide/show on each Trek Detail's comment
            // thread is the primary moderation surface; this cross-trek
            // overview is standalone and unlinked, same situation as
            // Registrations above.
            GoRoute(
              path: AppConstants.routeCommentModeration,
              name: 'admin-comment-moderation',
              builder: (context, state) => const CommentModerationScreen(),
              routes: [
                // /admin/comments/blocklist — add/remove blocklist terms
                // in-app. Nested here (relative, composes onto the full
                // path above) since it's a secondary tool of comment
                // moderation, not a first-class destination of its own —
                // see AdminBlocklistScreen's doc.
                GoRoute(
                  path: 'blocklist',
                  name: 'admin-comment-blocklist',
                  builder: (context, state) => const AdminBlocklistScreen(),
                ),
              ],
            ),
            // /admin/notifications — broadcast composer (Phase 8). The
            // one screen in this branch WITH a real entry point: the
            // admin-only "Send Notification" card on the Profile screen.
            GoRoute(
              path: AppConstants.routeAdminSendNotification,
              name: 'admin-send-notification',
              builder: (context, state) => const AdminSendNotificationScreen(),
            ),
            // /admin/merch-inquiries — "Buy Now" inquiry roster
            // (Version 2, Phase M2). Same shape as /admin/notifications:
            // reached only via Profile's "Merchandise Inquiries" card.
            GoRoute(
              path: AppConstants.routeAdminMerchInquiries,
              name: 'admin-merch-inquiries',
              builder: (context, state) => const AdminMerchInquiriesScreen(),
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
    //    /notifications, /admin + nested, or the inlined trek admin
    //    forms), redirect to Sign In. /notifications is protected for
    //    the same reason /profile is — notifications_select only
    //    allows authenticated readers, so a guest would just see a
    //    confusing empty list rather than genuinely private content,
    //    but redirecting is consistent with every other authenticated-
    //    only surface in this app rather than a special-cased silent
    //    empty state.
    final isProtectedRoute = location == AppConstants.routeProfile ||
        location == AppConstants.routeNotifications ||
        _isAdminRoute(location) ||
        _isTrekAdminRoute(location) ||
        _isMerchAdminRoute(location);
    if (sessionUser == null && isProtectedRoute) {
      return '${AppConstants.routeSignIn}?redirectTo=${Uri.encodeComponent(state.uri.toString())}';
    }

    // 3. If user is signed in and trying to visit /admin (or any nested
    //    /admin/... route), one of the trek admin forms now living
    //    under /trek-library, or a merchandise admin form under
    //    /merchandise, verify admin role. Checking the exact path
    //    alone would only gate /admin itself — a non-admin could still
    //    deep-link straight to /admin/registrations,
    //    /trek-library/new, or /merchandise/new otherwise, even though
    //    the UI never offers those to them.
    if (sessionUser != null &&
        (_isAdminRoute(location) || _isTrekAdminRoute(location) || _isMerchAdminRoute(location))) {
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
