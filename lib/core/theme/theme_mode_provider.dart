import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's light/dark preference.
///
/// Defaults to [ThemeMode.system], so a fresh install follows the OS
/// setting — which is what the direction asks for and what most users
/// expect. A manual override is offered in Profile → Appearance and is
/// persisted to [SharedPreferences] so it survives a restart.
///
/// Reading and writing are both synchronous because the underlying
/// [SharedPreferences] instance is resolved in `main()` before `runApp`
/// (see [sharedPreferencesProvider]). That matters here: resolving the
/// theme asynchronously would flash the wrong theme on every cold start.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  /// Persisted as a string rather than an enum index, so reordering
  /// [ThemeMode] in a future Flutter release can't silently repoint a
  /// stored preference at a different mode.
  static const String prefsKey = 'theme_mode';

  static ThemeMode _read(SharedPreferences prefs) => switch (prefs.getString(
    prefsKey,
  )) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    // Covers both an explicit 'system' and a missing/corrupt value.
    _ => ThemeMode.system,
  };

  static String _encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  /// Sets the preference and persists it.
  ///
  /// State updates first and the write is fire-and-forget: the toggle
  /// should feel instant, and a failed disk write costs the user a
  /// preference on next launch, not a broken UI now.
  void set(ThemeMode mode) {
    if (mode == state) return;
    state = mode;
    _prefs.setString(prefsKey, _encode(mode));
  }
}

/// The active [ThemeMode]. Feed this to `MaterialApp.themeMode`.
final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(ref.watch(sharedPreferencesProvider)),
  name: 'themeModeProvider',
);
