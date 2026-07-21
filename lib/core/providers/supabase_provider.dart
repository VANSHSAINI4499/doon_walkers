import 'package:doon_walkers/features/auth/data/models/user_model.dart';
import 'package:doon_walkers/features/auth/domain/entities/user_entity.dart';
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

/// Exposes the raw Supabase [AuthState] stream.
final authStateChangesProvider = StreamProvider<AuthState>(
  (ref) {
    final supabase = ref.watch(supabaseClientProvider);
    return supabase.auth.onAuthStateChange;
  },
  name: 'authStateChangesProvider',
);

/// Exposes the current user's profile row from `public.users` (`role`, `name`, etc.).
///
/// Automatically streams updates (such as manual admin role assignment in Supabase dashboard)
/// or yields null if no user is signed in.
final currentUserProvider = StreamProvider<UserModel?>(
  (ref) async* {
    ref.watch(authStateChangesProvider);
    final supabase = ref.watch(supabaseClientProvider);

    final sessionUser = supabase.auth.currentUser;
    if (sessionUser == null) {
      yield null;
      return;
    }

    // Stream live row updates from public.users table
    yield* supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', sessionUser.id)
        .map((rows) {
          if (rows.isEmpty) return null;
          return UserModel.fromJson(rows.first);
        });
  },
  name: 'currentUserProvider',
);

/// Derived boolean provider checking if the active user has the `admin` role.
///
/// Reads `.value` rather than `.when()`/pattern-matching the state, so a
/// transient RealtimeSubscribeException on the underlying stream (a
/// WebSocket reconnect — fires routinely on app background/foreground or
/// a network blip; see [currentUserProvider]) doesn't flip this to false
/// just because the state is momentarily AsyncError. Riverpod carries the
/// last-known [UserModel] through that transition via `copyWithPrevious`,
/// so `.value` still reflects the real role until a *confirmed* new value
/// (or a sign-out) replaces it.
final isAdminProvider = Provider<bool>(
  (ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.value?.role == UserRole.admin;
  },
  name: 'isAdminProvider',
);

/// Example trivial provider — demonstrates the Riverpod pattern works.
///
/// Replace with real app-version logic (e.g. from package_info_plus) in
/// a later phase. This exists purely to verify ProviderScope wiring.
final appVersionProvider = Provider<String>(
  (ref) => '1.0.0',
  name: 'appVersionProvider',
);
