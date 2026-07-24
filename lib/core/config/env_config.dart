import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralises access to environment-variable–based configuration.
///
/// Values are read once from the `.env` asset via [flutter_dotenv].
/// Call [EnvConfig.validate] early in `main()` to surface missing keys
/// before the app tries to use them.
class EnvConfig {
  EnvConfig._();

  /// Your Supabase project URL, e.g. `https://xyz.supabase.co`
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? '';

  /// Supabase anonymous (public) key — safe to embed in the client.
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Web OAuth client ID (client_type 3) from Google Cloud Console — used
  /// as [GoogleSignIn.serverClientId] so the ID token audience matches
  /// what Supabase's Google provider verifies against. Not a secret (it's
  /// sent to Google on every native sign-in request regardless), so it's
  /// safe alongside the anon key here rather than needing a server-only
  /// secret store.
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  /// Returns true when both required keys are present and non-empty.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Returns true when Google Sign-In has a web client ID to use. Checked
  /// separately from [isConfigured] since Google Sign-In is optional —
  /// the rest of the app (email/password auth) works without it.
  static bool get isGoogleSignInConfigured => googleWebClientId.isNotEmpty;

  /// MSG91 OTP Widget ID (MSG91 dashboard → OTP Widget). Client-embedded
  /// by design — see [msg91WidgetTokenAuth]'s doc.
  static String get msg91WidgetId => dotenv.env['MSG91_WIDGET_ID'] ?? '';

  /// MSG91 OTP Widget's scoped Token Auth — NOT the account-wide
  /// MSG91_AUTH_KEY (that one stays a server-only Supabase secret, used
  /// only by verify-phone-token). This one is deliberately meant to be
  /// embedded client-side: it's what lets `sendotp_flutter_sdk` call
  /// MSG91 directly from the device without ever exposing the real
  /// account authkey.
  static String get msg91WidgetTokenAuth => dotenv.env['MSG91_WIDGET_TOKEN_AUTH'] ?? '';

  /// Returns true when the OTP Widget has both values it needs to
  /// initialize. Checked separately from [isConfigured] for the same
  /// reason [isGoogleSignInConfigured] is — phone verification is one
  /// feature, not a prerequisite for the rest of the app.
  static bool get isPhoneWidgetConfigured =>
      msg91WidgetId.isNotEmpty && msg91WidgetTokenAuth.isNotEmpty;

  /// Prints a warning when keys are missing (non-fatal in Phase 1).
  static void validate() {
    if (!isConfigured) {
      // ignore: avoid_print
      print(
        '[EnvConfig] WARNING: SUPABASE_URL or SUPABASE_ANON_KEY is missing. '
        'Copy .env.example → .env and fill in your Supabase credentials.',
      );
    }
  }
}
