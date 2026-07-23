import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exposes the app's single [SharedPreferences] instance.
///
/// SharedPreferences.getInstance() is async, so this must be overridden
/// with a resolved value in main() before runApp — same
/// resolve-before-runApp shape as pushNotificationServiceProvider's
/// initialize() call. Reading this provider before that override runs
/// is a programming error (deliberately throws rather than returning a
/// stub), not a state this app is ever meant to reach.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in main()'),
  name: 'sharedPreferencesProvider',
);
