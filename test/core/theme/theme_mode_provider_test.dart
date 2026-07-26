// The theme preference is read synchronously at construction so a cold
// start never flashes the wrong theme. These tests pin that behaviour
// plus the encoding, which is deliberately a string rather than an enum
// index.

import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:doon_walkers/core/theme/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _containerWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to system when nothing is stored', () async {
    final container = await _containerWith({});
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('restores a stored preference', () async {
    for (final (stored, expected) in <(String, ThemeMode)>[
      ('light', ThemeMode.light),
      ('dark', ThemeMode.dark),
      ('system', ThemeMode.system),
    ]) {
      final container = await _containerWith({
        ThemeModeController.prefsKey: stored,
      });
      expect(container.read(themeModeProvider), expected);
    }
  });

  test('falls back to system on a corrupt stored value', () async {
    // A value written by a future version, or hand-edited. It must
    // degrade to the default rather than throw on launch.
    final container = await _containerWith({
      ThemeModeController.prefsKey: 'sepia',
    });
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('set() updates state and persists', () async {
    final container = await _containerWith({});
    final controller = container.read(themeModeProvider.notifier);

    controller.set(ThemeMode.dark);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeModeController.prefsKey), 'dark');
  });

  test('set() to the current mode is a no-op', () async {
    final container = await _containerWith({});
    final controller = container.read(themeModeProvider.notifier);

    var notifications = 0;
    container.listen(themeModeProvider, (_, _) => notifications++);

    controller.set(ThemeMode.system);
    expect(notifications, 0, reason: 'no state change, no rebuild');

    controller.set(ThemeMode.light);
    expect(notifications, 1);
  });
}
