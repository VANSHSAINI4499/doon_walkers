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
  static const String routeHome = '/';
  static const String routeAbout = '/about';
  static const String routeTrekLibrary = '/trek-library';
  static const String routeGallery = '/gallery';
  static const String routeUpcomingTreks = '/upcoming-treks';
  static const String routeProfile = '/profile';
  static const String routeAdmin = '/admin';
  static const String routeSignIn = '/sign-in';
  static const String routeSignUp = '/sign-up';
  static const String routeForgotPassword = '/forgot-password';

  // Nested routes (child GoRoutes under an existing top-level route —
  // see app_router.dart) — full locations for navigation call sites.
  static const String routeAdminTreks = '/admin/treks';
  static const String routeAdminTrekNew = '/admin/treks/new';
  static const String routeAdminGallery = '/admin/gallery';
  static const String routeAdminGalleryUpload = '/admin/gallery/upload';
  static String trekDetailLocation(String id) => '$routeTrekLibrary/$id';
  static String adminTrekEditLocation(String id) => '$routeAdminTreks/$id/edit';

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
}
