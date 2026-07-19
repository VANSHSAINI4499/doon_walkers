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

  /// Returns true when both required keys are present and non-empty.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

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
