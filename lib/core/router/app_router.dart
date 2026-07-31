import 'dart:async';
import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/motion/app_transitions.dart';
import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/widgets/app_shell.dart';
import 'package:doon_walkers/features/about/presentation/screens/about_screen.dart';
import 'package:doon_walkers/features/about/presentation/screens/contact_screen.dart';
import 'package:doon_walkers/features/about/presentation/screens/support_screen.dart';
import 'package:doon_walkers/features/activity/presentation/screens/insights_screen.dart';
import 'package:doon_walkers/features/activity/presentation/screens/monthly_goal_progress_screen.dart';
import 'package:doon_walkers/features/activity/presentation/screens/activity_screen.dart';
import 'package:doon_walkers/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:doon_walkers/features/auth/presentation/screens/phone_verification_screen.dart';
import 'package:doon_walkers/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:doon_walkers/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:doon_walkers/features/challenges/presentation/screens/admin_challenge_form_screen.dart';
import 'package:doon_walkers/features/challenges/presentation/screens/challenge_detail_screen.dart';
import 'package:doon_walkers/features/challenges/presentation/screens/challenge_leaderboard_screen.dart';
import 'package:doon_walkers/features/challenges/presentation/screens/challenges_screen.dart';
import 'package:doon_walkers/features/challenges/presentation/screens/my_challenge_achievements_screen.dart';
import 'package:doon_walkers/features/celebrations/presentation/screens/goal_celebration_screen.dart';
import 'package:doon_walkers/features/celebrations/presentation/screens/streak_celebration_screen.dart';
import 'package:doon_walkers/features/celebrations/presentation/screens/streak_details_screen.dart';
import 'package:doon_walkers/features/comments/presentation/screens/admin_blocklist_screen.dart';
import 'package:doon_walkers/features/comments/presentation/screens/comment_moderation_screen.dart';
import 'package:doon_walkers/features/community/domain/entities/member_directory_entry.dart';
import 'package:doon_walkers/features/community/presentation/screens/community_leaderboard_screen.dart';
import 'package:doon_walkers/features/community/presentation/screens/community_screen.dart';
import 'package:doon_walkers/features/community/presentation/screens/member_directory_screen.dart';
import 'package:doon_walkers/features/community/presentation/screens/member_profile_screen.dart';
import 'package:doon_walkers/features/design_demo/presentation/screens/design_system_demo_screen.dart';
import 'package:doon_walkers/features/gallery/presentation/screens/trek_gallery_screen.dart';
import 'package:doon_walkers/features/home/presentation/screens/home_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/admin_merch_inquiries_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/admin_product_form_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/merchandise_catalog_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/my_enquiries_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/product_detail_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/wishlist_screen.dart';
import 'package:doon_walkers/features/notifications/presentation/screens/admin_send_notification_screen.dart';
import 'package:doon_walkers/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:doon_walkers/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:doon_walkers/features/profile/presentation/screens/points_history_screen.dart';
import 'package:doon_walkers/features/profile/presentation/screens/profile_screen.dart';
import 'package:doon_walkers/features/profile/presentation/screens/achievements_screen.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/admin_registration_detail_screen.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/admin_registrations_screen.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/admin_trek_picker_screen.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/admin_trek_registrations_screen.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/my_registrations_screen.dart';
import 'package:doon_walkers/features/registrations/presentation/screens/trek_checkin_scan_screen.dart';
import 'package:doon_walkers/features/settings/presentation/screens/settings_screen.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/admin_trek_form_screen.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/trek_calendar_screen.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/trek_checkin_qr_screen.dart';
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
/// Exposed for test. Since Redesign 2.0 Phase 10 moved the admin screens
/// out of the shell to top-level routes, this predicate is the **only**
/// thing standing between a demoted admin and an admin screen they are
/// still sitting on — the shell's bespoke demotion listener was removed
/// as unreachable once `redirect` could be relied on again. It is worth
/// direct coverage on both sides.
@visibleForTesting
bool isAdminRoute(String location) => _isAdminRoute(location);

bool _isAdminRoute(String location) =>
    location == AppConstants.routeAdmin ||
    location.startsWith('${AppConstants.routeAdmin}/');

/// True for the admin-only trek create/edit forms — plus, since Phase
/// QR-1, the admin-only Check-in QR display — that now live under the
/// public `/trek-library` branch: `/trek-library/new`,
/// `/trek-library/:id/edit`, and `/trek-library/:id/checkin-qr`.
///
/// Without this, inlining the admin controls would have quietly widened
/// access: the forms used to sit behind `/admin/treks/...` and were
/// covered by [_isAdminRoute], so a non-admin deep-linking to them got
/// bounced. RLS (`treks_insert_admin` / `treks_update_admin` /
/// `trek_checkin_tokens_select_admin`) always rejected the actual
/// read/write either way, but showing a stranger a working-looking
/// screen that fails only once it tries to load or save is bad UX —
/// this keeps the pre-restructure behaviour of redirecting instead.
/// Exposed for test: the matching is easy to get subtly wrong (matching
/// the plain detail route would lock members out of trek pages entirely;
/// failing to match `/edit` or `/checkin-qr` would leave those forms
/// open to them), and there is no deep-link scheme registered on
/// Android to exercise it at runtime.
@visibleForTesting
bool isTrekAdminRoute(String location) => _isTrekAdminRoute(location);

bool _isTrekAdminRoute(String location) {
  if (location == AppConstants.routeTrekNew) return true;

  // Match the exact `/trek-library/{id}/edit` or `/trek-library/{id}/
  // checkin-qr` shape by segment count rather than a suffix check: a
  // plain `endsWith('/edit')` would also match `/trek-library/edit`,
  // which is really the *detail* route for a trek whose id happens to
  // be "edit".
  final segments = Uri.parse(location).pathSegments;
  return segments.length == 3 &&
      '/${segments.first}' == AppConstants.routeTrekLibrary &&
      (segments.last == 'edit' || segments.last == 'checkin-qr');
}

/// True for `/trek-library/:id/check-in` — the member-facing check-in
/// scanner (Phase QR-2). Deliberately separate from [_isTrekAdminRoute]:
/// this needs sign-in, not admin — it's added to `isProtectedRoute`
/// below, not to the admin-role check. Same segment-count matching
/// reasoning as [_isTrekAdminRoute] (a trek literally id'd "check-in"
/// must still resolve as the *detail* route).
@visibleForTesting
bool isTrekCheckinRoute(String location) => _isTrekCheckinRoute(location);

bool _isTrekCheckinRoute(String location) {
  final segments = Uri.parse(location).pathSegments;
  return segments.length == 3 &&
      '/${segments.first}' == AppConstants.routeTrekLibrary &&
      segments.last == 'check-in';
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
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return _buildRouter(ref, refreshNotifier);
}, name: 'routerProvider');

/// DoonWalkers application router.
///
/// Uses [GoRouter] with a [StatefulShellRoute] so that:
///   - Every primary tab maintains its own navigation stack.
///   - The [AppShell] (bottom nav + drawer) persists across route transitions.
///   - Auth routes (/sign-in, /sign-up, /forgot-password) are top-level outside
///     the shell so bottom navigation bars are suppressed.
///   - Every drawer destination (/merchandise, /about, /support,
///     /settings, /contact) and /notifications are ALSO top-level,
///     outside the shell. All are reached from an AppBar/drawer
///     affordance visible on every branch, so nesting any of them under
///     one specific branch would silently switch tabs depending on which
///     was current when it was opened.
///
/// ## Branch layout (Redesign 2.0, Phase 10)
///
/// Branches 0-4 are the bottom tabs and MUST stay in this order —
/// `goBranch(index)` takes a raw branch index, and [AppShell]'s
/// `_destinations` list mirrors it position for position:
///
///   0: Home          1: Activity     2: Trek Library
///   3: Challenges    4: Profile
///   5: Admin-only screens — **never a tab**, reached from the drawer's
///      Admin section.
///
/// The tab set is now identical for every role. Admin's extra Trek
/// Registrations tab is gone (the screen moved to the drawer), which
/// removes the role-dependent tab count that caused this shell's two
/// previous navigation incidents — see [AppShell] and
/// `resolveSelectedTabIndex`.
///
/// About was folded into Home back in Part B; Phase 10 pulled it back out
/// into its own drawer destination and removed it from Home rather than
/// duplicating it — see AboutScreen's doc. Gallery's standalone
/// cross-trek tab remains gone for every role; gallery MANAGEMENT stays
/// exactly where it was, inline on each Trek Detail page's
/// TrekGallerySection.
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
GoRouter _buildRouter(
  Ref ref,
  _RouterRefreshNotifier refreshNotifier,
) => GoRouter(
  // Read once, synchronously, at router construction — SharedPreferences
  // is already resolved before runApp() (see main.dart), same as
  // Supabase's currentUser is already resolved by the time this runs.
  // A device that has already seen onboarding boots straight to Home as
  // always; a fresh install (or one where this flag was never set)
  // lands on the carousel instead, which itself hands off to Sign In.
  initialLocation:
      (ref
                  .read(sharedPreferencesProvider)
                  .getBool(AppConstants.prefsHasSeenOnboarding) ??
              false)
          ? AppConstants.routeHome
          : AppConstants.routeOnboarding,
  debugLogDiagnostics: kDebugMode,
  refreshListenable: refreshNotifier,
  routes: [
    // First-launch intro carousel — top-level, outside the shell, no
    // bottom nav/drawer. Matches none of `redirect`'s auth/admin checks
    // below, so it needs no special-casing there.
    GoRoute(
      path: AppConstants.routeOnboarding,
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    // Top-Level Auth Routes (Outside AppShell)
    GoRoute(
      path: AppConstants.routeSignIn,
      name: 'sign-in',
      builder:
          (context, state) =>
              SignInScreen(redirectTo: state.uri.queryParameters['redirectTo']),
    ),
    GoRoute(
      path: AppConstants.routeSignUp,
      name: 'sign-up',
      builder:
          (context, state) =>
              SignUpScreen(redirectTo: state.uri.queryParameters['redirectTo']),
    ),
    GoRoute(
      path: AppConstants.routeForgotPassword,
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    // /verify-phone — Version 2, Phase Auth Upgrade. Top-level like the
    // other auth screens above, not nested under AppShell — reached via
    // AuthGuard.requirePhoneVerified, same shape as /sign-in.
    GoRoute(
      path: AppConstants.routePhoneVerification,
      name: 'verify-phone',
      builder:
          (context, state) => PhoneVerificationScreen(
            redirectTo: state.uri.queryParameters['redirectTo'],
          ),
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
    // Celebration system — top-level for the same reason as
    // /notifications: ActivitySyncController pushes these
    // programmatically right after a sync, which can happen from any
    // tab. See AppConstants.routeDailyGoalCelebration's doc.
    GoRoute(
      path: AppConstants.routeDailyGoalCelebration,
      name: 'daily-goal-celebration',
      builder: (context, state) {
        final data = state.extra as ({int steps, int goal})?;
        return GoalCelebrationScreen(
          steps: data?.steps ?? 0,
          goal: data?.goal ?? 0,
        );
      },
    ),
    GoRoute(
      path: AppConstants.routeStreakCelebration,
      name: 'streak-celebration',
      builder: (context, state) {
        final streakCount = state.extra as int? ?? 0;
        return StreakCelebrationScreen(streakCount: streakCount);
      },
    ),
    GoRoute(
      path: AppConstants.routeStreakDetails,
      name: 'streak-details',
      builder: (context, state) => const StreakDetailsScreen(),
    ),
    // ── Drawer destinations (Redesign 2.0, Phase 10) ────────────────
    // All top-level, outside the shell, for the same reason as
    // /notifications above: the drawer is visible on every branch, so
    // nesting any of these under one branch would switch tabs depending
    // on which happened to be current when it was opened.
    //
    // None are protected: About/Contact/Support read the same public
    // `public.settings` rows Home already reads, and Settings is
    // device-local appearance only. A guest can reach all four.
    GoRoute(
      path: AppConstants.routeAbout,
      name: 'about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: AppConstants.routeContact,
      name: 'contact',
      builder: (context, state) => const ContactScreen(),
    ),
    GoRoute(
      path: AppConstants.routeSupport,
      name: 'support',
      builder: (context, state) => const SupportScreen(),
    ),
    GoRoute(
      path: AppConstants.routeSettings,
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    // /profile/points-history — Phase 22. Top-level, NOT nested under the
    // Profile branch's route tree, same treatment as /settings above:
    // reached from a link on Profile, but registered here rather than
    // inside the StatefulShellBranch further down. See
    // AppConstants.routePointsHistory's doc.
    GoRoute(
      path: AppConstants.routePointsHistory,
      name: 'points-history',
      pageBuilder:
          (context, state) => AppTransitions.sharedAxisPage(
            key: state.pageKey,
            child: const PointsHistoryScreen(),
          ),
    ),
    GoRoute(
      path: AppConstants.routeAchievements,
      name: 'achievements',
      pageBuilder:
          (context, state) => AppTransitions.sharedAxisPage(
            key: state.pageKey,
            child: const AchievementsScreen(),
          ),
    ),
    // /design-system — the Redesign Phase 1 component gallery. A
    // developer/design review surface, not linked from any user-facing
    // navigation and reads no data; kept in the tree so the foundation
    // can be signed off before Phase 2 rebuilds real screens on it.
    // Uses a fade-through page as a live demo of AppTransitions.
    GoRoute(
      path: DesignSystemDemoScreen.routeName,
      name: 'design-system',
      pageBuilder:
          (context, state) => AppTransitions.fadeThroughPage(
            key: state.pageKey,
            child: const DesignSystemDemoScreen(),
          ),
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
          builder:
              (context, state) => ProductDetailScreen(
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
              builder:
                  (context, state) => AdminProductFormScreen(
                    productId: state.pathParameters['id']!,
                  ),
            ),
          ],
        ),
      ],
    ),

    // Top-level Challenges routes — reached via Drawer, Home shortcut,
    // or Community > Leaderboard CTA. Fully registered and deep-linkable.
    GoRoute(
      path: AppConstants.routeChallenges,
      name: 'challenges',
      builder: (context, state) => const ChallengesScreen(),
      routes: [
        GoRoute(
          path: 'history',
          name: 'challenges-history',
          builder: (context, state) => const MyChallengeAchievementsScreen(),
        ),
        GoRoute(
          path: ':id',
          name: 'challenge-detail',
          builder:
              (context, state) => ChallengeDetailScreen(
                challengeId: state.pathParameters['id']!,
              ),
          routes: [
            GoRoute(
              path: 'leaderboard',
              name: 'challenge-leaderboard',
              builder:
                  (context, state) => ChallengeLeaderboardScreen(
                    challengeId: state.pathParameters['id']!,
                  ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppConstants.routeAdminChallengesNew,
      name: 'admin-challenges-new',
      builder: (context, state) => const AdminChallengeFormScreen(),
    ),
    GoRoute(
      path: '${AppConstants.routeAdminChallenges}/:id/edit',
      name: 'admin-challenges-edit',
      builder:
          (context, state) => AdminChallengeFormScreen(
            challengeId: state.pathParameters['id']!,
          ),
    ),

    // Top-level Community sub-routes (outside StatefulShellRoute per nav crash prevention rule)
    GoRoute(
      path: '/community/leaderboard',
      name: 'community-leaderboard',
      builder: (context, state) => const CommunityLeaderboardScreen(),
    ),
    GoRoute(
      path: '/community/members',
      name: 'community-members',
      builder: (context, state) => const MemberDirectoryScreen(),
    ),
    GoRoute(
      path: '/community/members/profile',
      name: 'community-member-profile',
      builder: (context, state) {
        final member = state.extra as MemberDirectoryEntry?;
        if (member == null) {
          return const MemberDirectoryScreen();
        }
        return MemberProfileScreen(member: member);
      },
    ),

    // Phase 30 — Top-level Trek Calendar route (outside StatefulShellRoute)
    GoRoute(
      path: '/treks/calendar',
      name: 'treks-calendar',
      builder: (context, state) => const TrekCalendarScreen(),
    ),

    // StatefulShellRoute for App Navigation Tabs & Drawer Screens
    StatefulShellRoute.indexedStack(
      builder:
          (context, state, navigationShell) =>
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

        // Branch 1 — Activity (Redesign 2.0, Phase 10).
        //
        // A shared tab for every role, inserted between Home and Treks.
        // The screen is a placeholder this phase; Phase 11 fills in the
        // real Day/Week/Month content. The branch exists now so the tab
        // navigates for real rather than being wired up later — which is
        // how the index mapping stays derived once, here, instead of
        // being changed twice.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeActivity,
              name: 'activity',
              builder: (context, state) => const ActivityScreen(),
              routes: [
                // /activity/insights — nested so it pushes onto THIS
                // branch's stack, meaning back returns to the Activity tab
                // rather than to whatever tab was last visited.
                //
                // Nesting does NOT inherit the sign-in guard:
                // `isProtectedRoute` below matches locations by exact
                // equality, not by prefix, so this path is listed there
                // explicitly. Same reason /profile/wishlist etc. each have
                // their own entry.
                GoRoute(
                  path: 'insights',
                  name: 'activity-insights',
                  pageBuilder:
                      (context, state) => AppTransitions.sharedAxisPage(
                        key: state.pageKey,
                        child: const InsightsScreen(),
                      ),
                ),
                GoRoute(
                  path: 'goal-progress',
                  name: 'activity-goal-progress',
                  pageBuilder:
                      (context, state) => AppTransitions.sharedAxisPage(
                        key: state.pageKey,
                        child: const MonthlyGoalProgressScreen(),
                      ),
                ),
              ],
            ),
          ],
        ),

        // Branch 2 — Trek Library
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
                  builder:
                      (context, state) => TrekDetailScreen(
                        trekId: state.pathParameters['id']!,
                        // Set by TrekRegisterButton's sign-in return path so a
                        // guest who signed in mid-registration lands back in
                        // the form rather than just on the trek page.
                        openRegistration:
                            state.uri.queryParameters['register'] == '1',
                        // Set by CommentThread's "Sign in to comment" sign-in
                        // return path — same idea, for the comment input.
                        openComment:
                            state.uri.queryParameters['comment'] == '1',
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
                      builder:
                          (context, state) => AdminTrekFormScreen(
                            trekId: state.pathParameters['id']!,
                          ),
                    ),
                    // /trek-library/:id/checkin-qr — admin-only Display
                    // Check-in QR screen (Phase QR-1). Same placement
                    // reasoning as /edit above; trek_checkin_tokens_
                    // select_admin RLS is the real gate on the token.
                    GoRoute(
                      path: 'checkin-qr',
                      name: 'trek-checkin-qr',
                      builder:
                          (context, state) => TrekCheckinQrScreen(
                            trekId: state.pathParameters['id']!,
                          ),
                    ),
                    // /trek-library/:id/check-in — member-facing check-in
                    // scanner (Phase QR-2). A DIFFERENT last segment from
                    // /checkin-qr above on purpose (distinct screens, distinct
                    // audiences) — auth-required (any signed-in member, not
                    // admin-only), gated via isProtectedRoute below rather
                    // than _isTrekAdminRoute. verify_trek_checkin RPC is the
                    // real authorization boundary either way.
                    // /trek-library/:id/gallery — Trek Media Gallery
                    // rebuild's full paginated masonry screen, reached
                    // from TrekGalleryPreview's "+N · View All" tile.
                    // Public like the detail route itself; `title` is
                    // passed as a query param (the call site already
                    // has the trek's title loaded — same convention as
                    // `redirectTo`/`register=1` elsewhere in this file
                    // — rather than this screen re-fetching the trek
                    // just for its name).
                    GoRoute(
                      path: 'gallery',
                      name: 'trek-gallery',
                      builder:
                          (context, state) => TrekGalleryScreen(
                            trekId: state.pathParameters['id']!,
                            trekTitle: state.uri.queryParameters['title'] ?? '',
                          ),
                    ),
                    GoRoute(
                      path: 'check-in',
                      name: 'trek-check-in',
                      builder:
                          (context, state) => TrekCheckinScanScreen(
                            trekId: state.pathParameters['id']!,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Branch 3 — Community
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeCommunity,
              name: 'community',
              builder: (context, state) => const CommunityScreen(),
            ),
          ],
        ),

        // Branch 4 — Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppConstants.routeProfile,
              name: 'profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                // Profile dashboard redesign — the 3 "View All"
                // destinations each preview section's link opens.
                // pageBuilder (not builder) so these get the shared-axis
                // drill-in transition, the established idiom for
                // list/detail navigation in this design system.
                GoRoute(
                  path: 'wishlist',
                  name: 'my-wishlist',
                  pageBuilder:
                      (context, state) => AppTransitions.sharedAxisPage(
                        key: state.pageKey,
                        child: const WishlistScreen(),
                      ),
                ),
                GoRoute(
                  path: 'enquiries',
                  name: 'my-enquiries',
                  pageBuilder:
                      (context, state) => AppTransitions.sharedAxisPage(
                        key: state.pageKey,
                        child: const MyEnquiriesScreen(),
                      ),
                ),
                GoRoute(
                  path: 'registrations',
                  name: 'my-registrations',
                  pageBuilder:
                      (context, state) => AppTransitions.sharedAxisPage(
                        key: state.pageKey,
                        child: const MyRegistrationsScreen(),
                      ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // ── Admin-only screens (top-level, OUTSIDE the shell) ───────────
    //
    // Redesign 2.0 Phase 10 moved these out of the StatefulShellRoute.
    // They used to be a branch because Trek Registrations was a bottom
    // tab and `goBranch(index)` operates on branches. Now that every one
    // of them is reached from the drawer's Admin section, being a branch
    // was actively wrong: the drawer navigates with `push`, which does
    // NOT switch branches, so the shell's `currentIndex` stayed on
    // whatever tab was underneath. That broke the demotion guard (it
    // watched for the admin branch index, which was never reached) and
    // left the nav bar highlighting a tab the user was no longer on.
    //
    // As plain top-level routes they behave exactly like /merchandise
    // and /notifications: pushed over the shell with a back button, and
    // — critically — the router's own `redirect` re-evaluates against
    // their real top-level location, so a live demotion bounces a
    // stranded admin off them without needing a bespoke listener at all.
    //
    // Each keeps its literal `/admin/...` path purely so [_isAdminRoute]'s
    // prefix check goes on gating them unchanged.
    // /admin/trek-registrations — trek picker, then a trek-scoped
    // roster, then a registration's detail. Reached from the
    // drawer's Admin section (Phase 10; was an admin-only bottom
    // tab before that). The screens themselves are untouched.
    GoRoute(
      path: AppConstants.routeAdminTrekRegistrations,
      name: 'admin-trek-registrations',
      builder: (context, state) => const AdminTrekPickerScreen(),
      routes: [
        GoRoute(
          path: ':trekId',
          name: 'admin-trek-registrations-detail',
          builder:
              (context, state) => AdminTrekRegistrationsScreen(
                trekId: state.pathParameters['trekId']!,
              ),
          routes: [
            // /admin/trek-registrations/:trekId/:id — the same
            // AdminRegistrationDetailScreen the flat roster below
            // also opens, kept as a path nested here so this
            // roster's back stack stays self-describing. Both now
            // live in this one branch, so the cross-branch push
            // hazard the original nesting guarded against no
            // longer exists either way.
            GoRoute(
              path: ':id',
              name: 'admin-trek-registrations-registration-detail',
              builder:
                  (context, state) => AdminRegistrationDetailScreen(
                    registrationId: state.pathParameters['id']!,
                  ),
            ),
          ],
        ),
      ],
    ),
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
          builder:
              (context, state) => AdminRegistrationDetailScreen(
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

  // Auth Guard & Redirect Hook
  redirect: (context, state) {
    final supabase = Supabase.instance.client;
    final sessionUser = supabase.auth.currentUser;
    final location = state.uri.path;

    // Check if target is an auth screen
    final isAuthScreen =
        location == AppConstants.routeSignIn ||
        location == AppConstants.routeSignUp ||
        location == AppConstants.routeForgotPassword;

    // 1. If user is signed in and trying to visit an auth screen, redirect to destination or home
    if (sessionUser != null && isAuthScreen) {
      return state.uri.queryParameters['redirectTo'] ?? AppConstants.routeHome;
    }

    // 1b. Version 2, Phase Auth Upgrade — same shape as rule 1, but for
    //     /verify-phone: once the signed-in user's phone_verified flips
    //     true, bounce to destination or home. Driven by
    //     currentUserProvider's live stream (via _RouterRefreshNotifier),
    //     so this fires the instant verify-otp's write lands, not just
    //     on the next raw auth event — no `hasValue` guard needed here
    //     (unlike the admin check below) since the "still loading"
    //     default is simply staying on the verification screen, which is
    //     always safe, not a destructive kick like the admin case would be.
    if (sessionUser != null &&
        location == AppConstants.routePhoneVerification) {
      final userAsync = ref.read(currentUserProvider);
      if (userAsync.value?.phoneVerified == true) {
        return state.uri.queryParameters['redirectTo'] ??
            AppConstants.routeHome;
      }
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
    //    /challenges/history joins this list in Version 2, Phase C2 —
    //    a full destination screen (Personal Challenge History) reached
    //    by direct navigation, not one action inside an otherwise-public
    //    screen, so it gets the same router-level treatment as /profile
    //    rather than the client-side AuthGuard.requireAuth pattern
    //    Register/Wishlist/Buy use for in-screen actions.
    //    /verify-phone joins this list too — it presupposes a signed-in
    //    session (there's nothing to verify a phone number FOR
    //    otherwise), same reasoning as /profile.
    //    /trek-library/:id/check-in joins in Phase QR-2, same reasoning
    //    as /challenges/history — a full destination screen (the
    //    check-in scanner), not an in-screen action.
    //    /profile/wishlist, /profile/enquiries, /profile/registrations
    //    join for the Profile dashboard redesign — same reasoning as
    //    /challenges/history again: each is a full destination screen
    //    reached from a "View All" link, presupposing a signed-in
    //    session the same way the /profile page they're nested under
    //    already does.
    //    /profile/points-history joins in Phase 22, same reasoning —
    //    reached from Profile's points summary card, but registered
    //    top-level (see the route constant's own doc) rather than
    //    nested, so it needs its own explicit entry here.
    //    /activity joins this list in Redesign 2.0 Phase 10. It is a
    //    bottom tab visible to everyone (same as /profile), but
    //    everything it will ever show is the signed-in user's own
    //    movement data, so a guest tapping it is bounced to Sign In
    //    rather than shown a permanently empty dashboard. Wired now,
    //    while the screen is still a placeholder, so Phase 11 inherits
    //    the guard instead of having to remember to add it.
    final isProtectedRoute =
        location == AppConstants.routeProfile ||
        location == AppConstants.routeActivity ||
        location == AppConstants.routeActivityInsights ||
        location == AppConstants.routeMonthlyGoalProgress ||
        location == AppConstants.routeMyWishlist ||
        location == AppConstants.routeMyEnquiries ||
        location == AppConstants.routeMyRegistrations ||
        location == AppConstants.routePointsHistory ||
        location == AppConstants.routeAchievements ||
        location == AppConstants.routeNotifications ||
        location == AppConstants.routeChallengeHistory ||
        location == AppConstants.routePhoneVerification ||
        location == AppConstants.routeDailyGoalCelebration ||
        location == AppConstants.routeStreakCelebration ||
        location == AppConstants.routeStreakDetails ||
        _isAdminRoute(location) ||
        _isTrekAdminRoute(location) ||
        _isTrekCheckinRoute(location) ||
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
        (_isAdminRoute(location) ||
            _isTrekAdminRoute(location) ||
            _isMerchAdminRoute(location))) {
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

  errorBuilder:
      (context, state) =>
          Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
);
