// Guards the two behaviours that have survived every Profile redesign:
// the admin-only Send Notification / Merch Inquiries entry points appear
// ONLY for an admin, and the leaderboard-visibility toggle reflects (and is
// driven by) the real `showOnLeaderboard` column rather than local-only
// state.
//
// Phase 14 split Profile and Settings, which moved that toggle onto the
// Settings screen. The assertions follow it there rather than being
// deleted — where the control lives has changed twice now, what it must do
// has not.

import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/auth/data/models/user_model.dart';
import 'package:doon_walkers/features/auth/domain/entities/user_entity.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/admin_merch_inquiries_card.dart';
import 'package:doon_walkers/features/notifications/presentation/widgets/admin_send_notification_card.dart';
import 'package:doon_walkers/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserModel _user({required UserRole role, bool showOnLeaderboard = true}) => UserModel(
  id: 'u1',
  name: 'Asha',
  email: 'asha@example.com',
  role: role,
  createdAt: DateTime(2026, 1, 1),
  showOnLeaderboard: showOnLeaderboard,
);

Widget _host(Widget child, {required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: child),
  ),
);

/// Settings brings its own Scaffold and needs a signed-in session for the
/// Privacy/Activity sections to render, plus a real (mocked)
/// SharedPreferences instance — `_AppearanceSection` watches
/// `themeModeProvider`, whose controller reads `sharedPreferencesProvider`
/// in its constructor and throws if that provider is left unoverridden.
/// Without this, EVERY row after Theme silently fails to render, which is
/// exactly the bug this file's tests exist to catch.
Future<Widget> _settingsHost({
  required bool showOnLeaderboard,
  bool signedIn = true,
  ThemeData? theme,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      isSignedInProvider.overrideWith((ref) => signedIn),
      if (signedIn)
        currentUserProvider.overrideWith(
          (ref) => Stream.value(
            _user(role: UserRole.user, showOnLeaderboard: showOnLeaderboard),
          ),
        ),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.dark,
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  group('Admin-only entry points (gating preserved)', () {
    testWidgets('Send Notification shows for an admin, hidden for a member', (tester) async {
      await tester.pumpWidget(_host(
        const AdminSendNotificationCard(),
        overrides: [isAdminProvider.overrideWith((ref) => true)],
      ));
      await tester.pump();
      expect(find.text('Send Notification'), findsOneWidget);

      // Fully tear down before re-mounting under a fresh ProviderScope,
      // so the new isAdmin=false override actually takes effect.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_host(
        const AdminSendNotificationCard(),
        overrides: [isAdminProvider.overrideWith((ref) => false)],
      ));
      await tester.pump();
      expect(find.text('Send Notification'), findsNothing);
    });

    testWidgets('Merch Inquiries shows for an admin, hidden for a member', (tester) async {
      await tester.pumpWidget(_host(
        const AdminMerchInquiriesCard(),
        overrides: [isAdminProvider.overrideWith((ref) => true)],
      ));
      await tester.pump();
      expect(find.text('Merchandise Inquiries'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_host(
        const AdminMerchInquiriesCard(),
        overrides: [isAdminProvider.overrideWith((ref) => false)],
      ));
      await tester.pump();
      expect(find.text('Merchandise Inquiries'), findsNothing);
    });
  });

  group('Leaderboard visibility toggle (now on Settings)', () {
    testWidgets('reflects showOnLeaderboard = true', (tester) async {
      await tester.pumpWidget(await _settingsHost(showOnLeaderboard: true));
      await tester.pump();
      expect(find.text('Show me on leaderboards'), findsOneWidget);
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
    });

    testWidgets('reflects showOnLeaderboard = false (opted out)', (tester) async {
      await tester.pumpWidget(await _settingsHost(showOnLeaderboard: false));
      await tester.pump();
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);
    });

    testWidgets('renders in light theme too', (tester) async {
      await tester.pumpWidget(
        await _settingsHost(showOnLeaderboard: true, theme: AppTheme.light),
      );
      await tester.pump();
      expect(find.text('Show me on leaderboards'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Settings screen composition', () {
    testWidgets('shows every real setting and none of the unbacked ones', (
      tester,
    ) async {
      await tester.pumpWidget(await _settingsHost(showOnLeaderboard: true));
      await tester.pump();

      // Real, and each one writes somewhere.
      for (final label in [
        'Theme',
        'Daily step goal',
        'Show me on leaderboards',
        'About',
        'Contact us',
        'Sign out',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '"$label" missing');
      }

      // The reference listed these; none has a backing feature, so a row
      // for any of them would open nothing. Pinned so a later pass does
      // not add them back from the mockups.
      for (final absent in [
        'Account Settings',
        'Units & Display',
        'Blocked Users',
        'Community Guidelines',
        'Report a User',
        'Help Center',
      ]) {
        expect(
          find.text(absent),
          findsNothing,
          reason: '"$absent" has no backing feature and must not appear',
        );
      }
    });

    testWidgets('a guest sees only the device-local and public rows', (
      tester,
    ) async {
      // Settings is an unprotected drawer destination, so a guest can
      // reach it. Anything that writes to the user row is meaningless
      // without a session and must not render.
      await tester.pumpWidget(
        await _settingsHost(showOnLeaderboard: true, signedIn: false),
      );
      await tester.pump();

      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Daily step goal'), findsNothing);
      expect(find.text('Show me on leaderboards'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
    });
  });
}
