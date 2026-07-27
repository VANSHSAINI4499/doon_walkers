/// App-wide constants for DoonWalkers.
///
/// Keep organisation-specific strings here (not hardcoded in widgets)
/// so the app can later be adapted for other trekking communities by
/// editing this one file.
class AppConstants {
  AppConstants._();

  // ── App identity ────────────────────────────────────────────────
  static const String appName = 'Doon Walkers';
  static const String appTagline = 'Explore Dehradun with us';
  static const String appVersion = '1.0.0';

  // ── Organisation ────────────────────────────────────────────────
  static const String orgName = 'Doon Walkers';
  static const String orgCity = 'Dehradun';
  static const String orgState = 'Uttarakhand';
  static const String orgCountry = 'India';

  // ── Route paths (single source of truth for GoRouter) ───────────
  //
  // routeAbout and routeUpcomingTreks were removed in the Part B nav
  // restructure — About's content moved into Home, and the Upcoming
  // Treks tab (a "coming soon" placeholder with no real content) was
  // dropped entirely rather than replaced.
  //
  // routeGallery was removed in a later restructure — the standalone
  // cross-trek Gallery tab is gone for every role. Gallery MANAGEMENT
  // (admin add/delete) was never on this route to begin with; it lives
  // entirely on TrekGallerySection, embedded in each Trek Detail page,
  // and is unaffected by this removal.
  static const String routeHome = '/';
  static const String routeTrekLibrary = '/trek-library';
  static const String routeProfile = '/profile';
  static const String routeCommunity = '/community';

  /// Activity — the personal movement dashboard (Redesign 2.0, Phase 10
  /// creates the tab + route; Phase 11 fills in the real Day/Week/Month
  /// content). A shared bottom-nav tab for every role, sitting between
  /// Home and Treks.
  ///
  /// Protected like [routeProfile]: everything this tab will ever show is
  /// the signed-in user's own activity, so a guest tapping it is bounced
  /// to Sign In rather than shown an empty shell. Wiring that now — while
  /// the screen is still a placeholder — means Phase 11 inherits the
  /// guard instead of having to remember to add it.
  static const String routeActivity = '/activity';

  /// Activity Insights — the monthly read, pushed from the Activity tab's
  /// app bar (Redesign 2.0, Phase 11). Nested under [routeActivity] so it
  /// inherits that path's sign-in guard automatically rather than needing
  /// its own entry in `isProtectedRoute`.
  static const String routeActivityInsights = '$routeActivity/insights';
  static const String routeMonthlyGoalProgress = '$routeActivity/goal-progress';

  // ── Drawer destinations (Redesign 2.0, Phase 10) ──────────────────
  // Thin screens over data the app already has: [routeAbout],
  // [routeContact] and [routeSupport] all read `public.settings` via
  // settingsProvider and add no backend. [routeSettings] is device-local
  // preferences only.
  //
  // All four are top-level, OUTSIDE the StatefulShellRoute — same
  // reasoning as [routeNotifications] and [routeMerchandise]: they are
  // opened from the drawer, which is visible on every branch, so nesting
  // one under a single branch would silently switch tabs depending on
  // which was current when it was opened.

  /// Org identity, story, vision/mission, community rules. Moved out of
  /// Home entirely in Phase 10 — see AboutScreen's doc for why it is no
  /// longer duplicated there.
  static const String routeAbout = '/about';

  /// Contact channels (Instagram, WhatsApp, email, phone).
  static const String routeContact = '/contact';

  /// Getting help — the subset of contact channels that actually reach a
  /// human, plus the community rules.
  static const String routeSupport = '/support';

  /// Device-local preferences. Currently appearance (light/dark/system)
  /// only.
  static const String routeSettings = '/settings';

  /// Profile dashboard redesign — the member-facing "View All" screens
  /// for the three preview sections on Profile. Nested under
  /// [routeProfile] (registered in app_router.dart), each its own
  /// standalone destination — deliberately distinct paths/names from
  /// the ADMIN rosters ([routeAdminRegistrations]/
  /// [routeAdminTrekRegistrations]), which these do not replace or
  /// affect.
  static const String routeMyWishlist = '$routeProfile/wishlist';
  static const String routeMyEnquiries = '$routeProfile/enquiries';
  static const String routeMyRegistrations = '$routeProfile/registrations';

  /// Full points ledger (Phase 22) — reached from Profile's points
  /// summary card "View History" link. Registered top-level in
  /// app_router.dart exactly like [routeSettings], NOT nested under the
  /// Profile branch's own route tree — the phase brief calls this out
  /// explicitly, and it matches [routeSettings]'s precedent for "a full
  /// destination reached from a link on Profile". Router-level
  /// auth-gated (added to `isProtectedRoute`), same treatment as
  /// [routeChallengeHistory].
  static const String routePointsHistory = '$routeProfile/points-history';
  static const String routeAchievements = '$routeProfile/achievements';

  /// First-launch intro carousel — top-level, outside the shell, shown
  /// at most once per device. See app_router.dart's `_buildRouter` for
  /// the `initialLocation` check that gates this on
  /// [prefsHasSeenOnboarding]; nothing in `redirect` references this
  /// path, since it matches none of that function's existing auth/admin
  /// checks and needs none.
  static const String routeOnboarding = '/onboarding';

  /// No GoRoute matches this bare path anymore — the Admin Dashboard
  /// screen that used to live here (a static "access verified" banner
  /// plus a module-card grid) was removed once every card had an
  /// inline/tab equivalent elsewhere or (Send Notification) moved onto
  /// Profile. Kept only as the prefix app_router.dart's admin route
  /// guard matches against, since every surviving admin-only screen's
  /// path still starts with `/admin/...`.
  static const String routeAdmin = '/admin';
  static const String routeSignIn = '/sign-in';
  static const String routeSignUp = '/sign-up';
  static const String routeForgotPassword = '/forgot-password';

  /// Phone/OTP verification (Version 2, Phase Auth Upgrade) — reached via
  /// [AuthGuard.requirePhoneVerified] the same way [routeSignIn] is
  /// reached via [AuthGuard.requireAuth]: a `redirectTo` query param
  /// carries the original page back to app_router.dart's `redirect`,
  /// which bounces away automatically once phone_verified flips true.
  static const String routePhoneVerification = '/verify-phone';

  // Nested routes (child GoRoutes under an existing top-level route —
  // see app_router.dart) — full locations for navigation call sites.
  //
  // Trek create/edit live under the *public* /trek-library branch rather
  // than a separate /admin/treks section: admin controls are rendered
  // inline on the public Treks screen now, so the form they open belongs
  // to that same branch (keeps the bottom-nav tab selected while editing).
  // Admin-gating happens via isAdminProvider in the UI plus the
  // treks_insert_admin/treks_update_admin RLS policies server-side.
  static const String routeTrekNew = '$routeTrekLibrary/new';
  static String trekDetailLocation(String id) => '$routeTrekLibrary/$id';
  static String trekEditLocation(String id) => '$routeTrekLibrary/$id/edit';

  /// Admin "Display Check-in QR" screen (Phase QR-1) — nested under the
  /// trek detail route it's reached from, same shape as
  /// [trekEditLocation]. Gated by `_isTrekAdminRoute` in app_router.dart
  /// alongside `/edit`; `trek_checkin_tokens_select_admin` RLS is the
  /// real gate on the token itself either way.
  static String trekCheckinQrLocation(String id) =>
      '$routeTrekLibrary/$id/checkin-qr';

  /// Trek Media Gallery rebuild — the full paginated masonry gallery
  /// for one trek, reached from [TrekGalleryPreview]'s "+N · View All"
  /// tile once a trek has more than 5 items. Nested under the trek
  /// detail route it's reached from, same shape as
  /// [trekCheckinQrLocation]. Publicly browsable (no admin gate) —
  /// same audience as the embedded preview it expands from; the admin
  /// upload/delete affordances are conditionally rendered inline, not
  /// route-gated.
  static String trekGalleryLocation(String id) =>
      '$routeTrekLibrary/$id/gallery';

  /// Cross-trek registrations roster — kept as its own admin destination
  /// since it has no single-trek screen to inline into. No UI entry
  /// point links here since the Admin Dashboard grid was removed; still
  /// registered as a standalone route in app_router.dart, just currently
  /// unreachable except by direct navigation.
  static const String routeAdminRegistrations = '/admin/registrations';

  /// Per-registration admin detail (sensitive fields + payment control).
  /// Nested under the roster so `_isAdminRoute` gates it automatically.
  static String adminRegistrationDetailLocation(String id) =>
      '$routeAdminRegistrations/$id';

  /// Per-trek registrations — trek picker (this path) plus a trek-scoped
  /// roster ([adminTrekRegistrationsLocation]). A separate destination
  /// from [routeAdminRegistrations] (the flat cross-trek roster) rather
  /// than a filter on it — they serve different workflows: the flat
  /// roster is recency-triage across every trek, this is a single
  /// trek's full attendee list.
  ///
  /// **No longer a bottom-nav tab.** Redesign 2.0 Phase 10 moved this to
  /// the drawer's admin section: the bottom nav is now five shared tabs
  /// for every role, so admin no longer gets an extra one. The screen
  /// itself is untouched — only its entry point moved.
  ///
  /// The practical cost: an admin's most-used roster went from one tap
  /// anywhere to two (menu → Registrations). Flagged, and accepted as
  /// part of making the tab bar role-independent.
  static const String routeAdminTrekRegistrations = '/admin/trek-registrations';

  /// The roster for one trek, nested under [routeAdminTrekRegistrations]
  /// so it inherits the `/admin` prefix gate automatically.
  static String adminTrekRegistrationsLocation(String trekId) =>
      '$routeAdminTrekRegistrations/$trekId';

  /// A registration's detail view, reached from the per-trek roster.
  ///
  /// Still deliberately NOT [adminRegistrationDetailLocation], though the
  /// original reason has lapsed: the two used to live in different
  /// StatefulShellRoute branches, so pushing across them switched tabs
  /// and put "back" on the wrong screen. Since Phase 10 folded Trek
  /// Registrations into the single admin branch, both paths now share a
  /// navigator and either would work. Keeping the nested path anyway —
  /// it keeps this roster's back stack self-describing, and re-pointing
  /// live call sites for no behavioural gain is exactly the kind of
  /// churn that caused this file's earlier navigation incidents.
  static String adminTrekRegistrationsDetailLocation(
    String trekId,
    String registrationId,
  ) => '${adminTrekRegistrationsLocation(trekId)}/$registrationId';

  /// Cross-trek comment moderation queue — every currently-hidden
  /// comment across every trek. Drawer/dashboard-only like
  /// [routeAdminRegistrations], not a bottom-nav tab: inline hide/show
  /// on each comment (on Trek Detail) is the primary moderation
  /// surface; this is the "what have I already hidden, anywhere"
  /// overview, same relationship [routeAdminRegistrations] has to
  /// [routeAdminTrekRegistrations].
  static const String routeCommentModeration = '/admin/comments';

  /// In-app blocklist management (add/remove terms) — the real,
  /// ongoing answer to keeping `public.comment_blocklist` current,
  /// reachable without touching code or the Supabase dashboard.
  /// Nested under [routeCommentModeration], not its own Admin
  /// Dashboard destination — see AdminBlocklistScreen's doc.
  static const String routeCommentBlocklist =
      '$routeCommentModeration/blocklist';

  /// In-app notification list — top-level, OUTSIDE the StatefulShellRoute
  /// entirely (like /sign-in), not nested under any bottom-nav branch.
  /// The bell icon that opens it lives in AppShell's AppBar, which is
  /// visible from every branch (Home/Treks/Profile/Registrations) — if
  /// this were nested under any ONE of them, opening it from a
  /// different branch would silently switch tabs (the exact bug class
  /// fixed in the nav restructure: push() resolves to whichever branch
  /// a route structurally belongs to, regardless of what's currently
  /// visible). A plain top-level route sidesteps that entirely.
  static const String routeNotifications = '/notifications';

  /// Admin composer — broadcast a title+body to every registered
  /// device. Nested under /admin like Comment Moderation/Registrations
  /// (drawer/dashboard-only, not a bottom-nav tab).
  static const String routeAdminSendNotification = '/admin/notifications';

  /// Merchandise Catalog — Version 2, Phase M1. A plain top-level route
  /// OUTSIDE the StatefulShellRoute, same reasoning as
  /// [routeNotifications]: it's reached from the Navigation Drawer,
  /// which (like the AppBar's bell icon) is visible from every branch,
  /// so nesting it under any ONE branch would silently switch tabs
  /// depending on which was current when the drawer opened. Not a
  /// bottom-nav tab — see MerchandiseCatalogScreen's doc for the full
  /// placement reasoning. Publicly browsable (no sign-in redirect);
  /// only the admin create/edit forms below are admin-gated.
  static const String routeMerchandise = '/merchandise';

  /// Admin create form. Admin-gated the same way [routeTrekNew] is —
  /// see app_router.dart's `_isMerchAdminRoute`.
  static const String routeMerchandiseNew = '$routeMerchandise/new';

  static String merchandiseDetailLocation(String id) => '$routeMerchandise/$id';

  /// Admin edit form, nested under the detail route it edits — mirrors
  /// [trekEditLocation]'s shape exactly.
  static String merchandiseEditLocation(String id) =>
      '$routeMerchandise/$id/edit';

  /// Admin "Buy Now" inquiries roster — Version 2, Phase M2. Under
  /// `/admin/...` so the EXISTING `_isAdminRoute` prefix check already
  /// gates it (viewing this list is admin-only outright, unlike the
  /// public catalog, so it doesn't need its own `_isMerchAdminRoute`-
  /// style guard — the blanket admin check is exactly what's wanted
  /// here). Reachable only via Profile's "Merchandise Inquiries" card
  /// — see AdminMerchInquiriesCard.
  static const String routeAdminMerchInquiries = '/admin/merch-inquiries';

  /// Path prefix for the admin challenge create/edit forms — NOT a
  /// screen of its own (there is no bare `/admin/challenges` route).
  /// C1 gave this its own admin-only bottom-nav tab with a full list
  /// screen at this exact path; C2 retired that tab once
  /// [routeChallenges] gave Challenges a real public tab that admin
  /// now also manages from inline (see ChallengeAdminActions on
  /// ChallengesScreen) — kept only as the prefix
  /// [routeAdminChallengesNew]/[adminChallengeEditLocation] build on,
  /// still covered by the existing `_isAdminRoute` prefix check with
  /// no dedicated guard needed.
  static const String routeAdminChallenges = '/admin/challenges';

  /// Declared BEFORE `:id` in app_router.dart, same reasoning as
  /// [routeTrekNew]/[routeMerchandiseNew].
  static const String routeAdminChallengesNew = '$routeAdminChallenges/new';

  static String adminChallengeEditLocation(String id) =>
      '$routeAdminChallenges/$id/edit';

  /// Public Challenges tab (Version 2, Phase C2) — browsable by guests
  /// (RLS already scopes drafts to admin-only via `challenges_select`);
  /// no redirect guard here, same as [routeMerchandise]. Admin sees the
  /// same screen plus inline management (drafts included, marked as
  /// such, an actions menu, an "Add Challenge" FAB) — mirrors
  /// TrekLibraryScreen's single-shared-screen pattern exactly, not a
  /// separate admin screen.
  static const String routeChallenges = '/challenges';

  static String challengeDetailLocation(String id) => '$routeChallenges/$id';

  /// Nested under the challenge detail route it's reached from —
  /// Version 2, Phase C3. See ChallengeLeaderboardScreen's doc for why
  /// there's no standalone leaderboard tab.
  static String challengeLeaderboardLocation(String id) =>
      '$routeChallenges/$id/leaderboard';

  /// Member-facing check-in scan screen (Phase QR-2) — nested under the
  /// trek detail route, same shape as [trekCheckinQrLocation] but a
  /// DIFFERENT last segment ('check-in' vs 'checkin-qr') and a
  /// different audience: any signed-in member, not admin-only. Router-
  /// level auth-gated (see `isProtectedRoute` in app_router.dart) —
  /// this is a full destination screen reached by direct navigation,
  /// not an in-screen action, same category as [routeChallengeHistory]
  /// per that constant's own doc. `verify_trek_checkin` RPC is the real
  /// authorization boundary either way (a signed-in but unregistered
  /// caller reaching this screen just gets DWC01 back on scan).
  static String trekCheckInLocation(String id) =>
      '$routeTrekLibrary/$id/check-in';

  /// Declared BEFORE `:id` in app_router.dart, same reasoning as every
  /// other `new`-before-`:id` ordering in this file — without it,
  /// "history" would be captured as a challenge id instead.
  ///
  /// Router-level guarded (added to `isProtectedRoute` in
  /// app_router.dart, same treatment as [routeProfile]/
  /// [routeNotifications]) rather than the client-side
  /// AuthGuard.requireAuth pattern Register/Wishlist/Buy use — this is
  /// a full destination screen reached by direct navigation, not one
  /// action within an otherwise-public screen, so it fits the
  /// "whole screen requires sign-in" case those two already establish.
  static const String routeChallengeHistory = '$routeChallenges/history';

  // ── Supabase table names ─────────────────────────────────────────
  static const String tableUsers = 'users';
  static const String tableTreks = 'treks';
  static const String tableGallery = 'gallery';
  static const String tableComments = 'comments';
  static const String tableRegistrations = 'registrations';
  static const String tableNotifications = 'notifications';
  static const String tableSettings = 'settings';

  /// Admin-editable content-filter blocklist (0012_comments_moderation.sql).
  static const String tableCommentBlocklist = 'comment_blocklist';

  /// Per-device FCM tokens (0014_device_tokens.sql) — no client SELECT
  /// policy at all; see that migration's doc for why.
  static const String tableDeviceTokens = 'device_tokens';

  /// Merchandise catalog (0016_merchandise_catalog.sql).
  static const String tableProducts = 'products';

  /// Optional per-size stock, one-to-many with [tableProducts]. Empty
  /// for a product with no sizes — see the Product entity's doc.
  static const String tableProductVariants = 'product_variants';

  /// One-to-many product photos, mirrors [tableGallery]'s shape.
  static const String tableProductImages = 'product_images';

  /// "Buy Now" inquiries (0018_merch_inquiries.sql) — an
  /// inquiry-to-admin flow, not real checkout. See MerchInquiryRepository.
  static const String tableMerchInquiries = 'merch_inquiries';

  /// A user's saved products (0019_user_wishlist.sql) — own-row only,
  /// deliberately no admin visibility; see that migration's doc.
  static const String tableUserWishlist = 'user_wishlist';

  /// Challenge definitions (0022_challenges.sql) — Version 2, Phase C1.
  static const String tableChallenges = 'challenges';

  /// One row per (challenge, tier) — one-to-many with [tableChallenges],
  /// always all 4 tiers together; see the Challenge entity's doc.
  static const String tableChallengeTiers = 'challenge_tiers';

  /// One row per (user, challenge) enrollment — Phase 21, 0038_challenge_
  /// enrollments.sql. Authenticated SELECT for participant counts;
  /// own-row INSERT/DELETE for the member; admin ALL.
  static const String tableChallengeEnrollments = 'challenge_enrollments';

  /// One row per (user, calendar date) of synced fitness activity
  /// (0027_daily_activity_summary.sql) — Version 2, Challenges Module
  /// pivot. Own-row only, no admin visibility; see that migration's
  /// doc. This is what ActivitySyncService writes to and the challenge
  /// RPCs read from — see ActivityProvider's doc for the full pipeline.
  static const String tableDailyActivitySummary = 'daily_activity_summary';

  /// Per-user points/level totals (0036_phase19_schema_foundations.sql) —
  /// Phase 19. `level` is maintained server-side by `award_points()`/
  /// `level_for_points()`; never recompute it client-side.
  static const String tableUserPoints = 'user_points';

  /// Append-only signed-points log (0036_phase19_schema_foundations.sql).
  /// Own-row SELECT RLS already scopes reads to the caller, so Points
  /// History (Phase 22) reads this directly rather than through an RPC —
  /// same pattern as [tableDailyActivitySummary].
  static const String tablePointsLedger = 'points_ledger';

  /// One row per trek, auto-created by a DB trigger on trek insert
  /// (0029_trek_checkin_qr.sql) — Phase QR-1. Admin-only SELECT, no
  /// client write policy at all; see that migration's doc for why the
  /// token lives here rather than as a column on [tableTreks].
  static const String tableTrekCheckinTokens = 'trek_checkin_tokens';

  // ── Supabase RPC functions ───────────────────────────────────────

  /// Live-computes the SIGNED-IN caller's progress across every active
  /// challenge — see ChallengeRepository.fetchMyProgress's doc for why
  /// this takes no user-id parameter (auth.uid() is read inside the
  /// function itself; that's the entire security model for it).
  static const String rpcGetMyChallengeProgress = 'get_my_challenge_progress';

  /// Live-computes the real DATE the signed-in caller reached each
  /// tier they've actually reached, per challenge (0023_challenge_tier_
  /// history.sql) — same no-parameter security model as
  /// [rpcGetMyChallengeProgress].
  static const String rpcGetMyChallengeTierHistory =
      'get_my_challenge_tier_history';

  /// Phase QR-2 (0030_trek_checkin_verify.sql) — validates a scanned
  /// check-in QR and, if every check passes, records
  /// `registrations.checked_in_at`. Takes `p_trek_id`/`p_token`; reads
  /// auth.uid() internally, same no-user-id-param security model as
  /// [rpcGetMyChallengeProgress]. Raises a specific custom SQLSTATE
  /// (DWC01–DWC06) per failure reason — see
  /// RegistrationRepositoryImpl.verifyCheckin's doc for the mapping.
  static const String rpcVerifyTrekCheckin = 'verify_trek_checkin';

  /// Live-computes the SIGNED-IN caller's current/longest trekking
  /// streak in consecutive calendar months (0024_streaks.sql) —
  /// Version 2, Phase C3. Same no-parameter security model as
  /// [rpcGetMyChallengeProgress]. Not scoped to any challenge — a
  /// general attendance-consistency stat.
  static const String rpcGetMyStreak = 'get_my_streak';

  /// How the caller's monthly step total ranks against other tracking
  /// members, as a single percentage (0035_activity_percentile.sql) —
  /// Redesign 2.0, Phase 11. Aggregate-only and SECURITY DEFINER, the
  /// same privacy posture as `get_community_stats()`: it returns one
  /// integer and cannot expose another member's activity rows.
  ///
  /// Returns NULL when fewer than 5 members tracked that month (a
  /// k-anonymity floor) or when the caller has no data for it.
  static const String rpcGetMyActivityPercentile = 'get_my_activity_percentile';
  static const String rpcGetDailyActivityPercentile =
      'get_daily_activity_percentile';

  /// Ranks every leaderboard-visible user by their progress on ONE
  /// challenge (0025_leaderboard.sql) — Version 2, Phase C3. Takes a
  /// challenge id parameter (unlike the auth.uid()-internal RPCs
  /// above) since it's showing OTHER users' standings, not just the
  /// caller's own; the privacy boundary is the function's fixed
  /// `(display_name, rank, score)` return shape plus its own
  /// `show_on_leaderboard = TRUE` filter, not RLS. See
  /// ChallengeRepository.fetchLeaderboard's doc.
  static const String rpcGetChallengeLeaderboard = 'get_challenge_leaderboard';

  /// Phase 21 (0038_challenge_enrollments.sql) — enrolls the signed-in
  /// user in a challenge and awards a 10-pt welcome bonus.
  static const String rpcEnrollInChallenge = 'enroll_in_challenge';

  /// Phase 21 — removes the signed-in user's enrollment. Points are kept.
  static const String rpcUnenrollFromChallenge = 'unenroll_from_challenge';

  /// Phase 21 — returns the BIGINT count of enrolled users for a challenge.
  static const String rpcGetChallengeParticipantCount =
      'get_challenge_participant_count';

  /// Phase 21 — returns top N enrolled participants ordered by live score,
  /// with total_points and level from user_points for level badge display.
  static const String rpcGetChallengeTopParticipants =
      'get_challenge_top_participants';

  /// Phase 22 (0039_points_history_and_enrollment_fix.sql) — the
  /// signed-in caller's total_points/level plus how many points are
  /// needed for the next level. `level_for_points()`/`points_for_level()`
  /// are the ONE source of truth for the level ladder (extracted out of
  /// `award_points()`); this RPC is how the client reads it instead of
  /// hardcoding the ladder in Dart. Same no-parameter, auth.uid()-
  /// internal security model as [rpcGetMyChallengeProgress].
  static const String rpcGetMyPointsSummary = 'get_my_points_summary';

  // ── Supabase Storage buckets ─────────────────────────────────────
  static const String bucketTrekCovers = 'trek-covers';
  static const String bucketTrekGallery = 'trek-gallery';

  /// PRIVATE bucket (0011_payment_verification.sql) — unlike the two
  /// above, this is not public-read. Every object is scoped to the
  /// registration it belongs to; see RegistrationRepository for the
  /// upload/signed-URL flow.
  static const String bucketPaymentProofs = 'payment-proofs';

  /// Product photos (0017_merch_images_storage.sql) — a NEW bucket, not
  /// a reuse of trek-covers/trek-gallery; same public-read/admin-write
  /// shape as trek-covers.
  static const String bucketMerchImages = 'merch-images';

  // ── SharedPreferences keys ───────────────────────────────────────

  /// Device-level "has this install seen the onboarding carousel"
  /// flag — deliberately not tied to any signed-in account (a guest
  /// browsing without ever signing in should still only see it once).
  static const String prefsHasSeenOnboarding = 'has_seen_onboarding';
}
