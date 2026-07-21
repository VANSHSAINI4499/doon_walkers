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
  static const String routeHome = '/';
  static const String routeTrekLibrary = '/trek-library';
  static const String routeGallery = '/gallery';
  static const String routeProfile = '/profile';
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
  /// since it has no single-trek screen to inline into.
  static const String routeAdminRegistrations = '/admin/registrations';

  /// Per-registration admin detail (sensitive fields + payment control).
  /// Nested under the roster so `_isAdminRoute` gates it automatically.
  static String adminRegistrationDetailLocation(String id) =>
      '$routeAdminRegistrations/$id';

  // ── Supabase table names ─────────────────────────────────────────
  static const String tableUsers = 'users';
  static const String tableTreks = 'treks';
  static const String tableGallery = 'gallery';
  static const String tableComments = 'comments';
  static const String tableRegistrations = 'registrations';
  static const String tableNotifications = 'notifications';
  static const String tableSettings = 'settings';

  // ── Supabase Storage buckets ─────────────────────────────────────
  static const String bucketTrekCovers = 'trek-covers';
  static const String bucketTrekGallery = 'trek-gallery';

  /// PRIVATE bucket (0011_payment_verification.sql) — unlike the two
  /// above, this is not public-read. Every object is scoped to the
  /// registration it belongs to; see RegistrationRepository for the
  /// upload/signed-URL flow.
  static const String bucketPaymentProofs = 'payment-proofs';
}
