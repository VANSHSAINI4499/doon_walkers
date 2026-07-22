/// App-wide constants for DoonWalkers.
///
/// Keep organisation-specific strings here (not hardcoded in widgets)
/// so the app can later be adapted for other trekking communities by
/// editing this one file.
class AppConstants {
  AppConstants._();

  // ── App identity ────────────────────────────────────────────────
  static const String appName = 'Doon Walkers';
  static const String appTagline = 'Explore the Himalayas with us';
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
  /// Promoted to its own bottom-nav TAB (branch) for admins in the final
  /// nav restructure, unlike [routeAdminRegistrations] which has no UI
  /// entry point at all now — important enough to an admin's day-to-day
  /// use to deserve one tap from anywhere, not two.
  static const String routeAdminTrekRegistrations = '/admin/trek-registrations';

  /// The roster for one trek, nested under [routeAdminTrekRegistrations]
  /// so it inherits the `/admin` prefix gate automatically.
  static String adminTrekRegistrationsLocation(String trekId) =>
      '$routeAdminTrekRegistrations/$trekId';

  /// A registration's detail view, reached from the per-trek roster.
  /// Deliberately NOT [adminRegistrationDetailLocation] (the flat
  /// roster's path under the /admin branch) — that belongs to a
  /// different StatefulShellRoute branch than this tab, and pushing
  /// across branches would switch tabs and put "back" on the Admin
  /// Dashboard instead of this trek's roster. Same screen, a path
  /// nested under this branch instead.
  static String adminTrekRegistrationsDetailLocation(String trekId, String registrationId) =>
      '${adminTrekRegistrationsLocation(trekId)}/$registrationId';

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
  static const String routeCommentBlocklist = '$routeCommentModeration/blocklist';

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
  static String merchandiseEditLocation(String id) => '$routeMerchandise/$id/edit';

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
}
