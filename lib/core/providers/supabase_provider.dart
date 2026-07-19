import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the initialised [SupabaseClient] as a Riverpod provider.
///
/// Usage:
/// ```dart
/// final supabase = ref.read(supabaseClientProvider);
/// ```
///
/// Supabase.initialize() must have been called in main() before any widget
/// accesses this provider.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
  name: 'supabaseClientProvider',
);

/// Example trivial provider — demonstrates the Riverpod pattern works.
///
/// Replace with real app-version logic (e.g. from package_info_plus) in
/// a later phase. This exists purely to verify ProviderScope wiring.
final appVersionProvider = Provider<String>(
  (ref) => '1.0.0',
  name: 'appVersionProvider',
);
