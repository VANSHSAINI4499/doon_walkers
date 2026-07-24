// Guards the Profile screen's most critical preserved conditionals across
// the Phase 5 redesign: the admin-only Send Notification / Merch Inquiries
// entry points appear ONLY for an admin, and the leaderboard-visibility
// toggle reflects (and is driven by) the real `showOnLeaderboard` field
// rather than local-only state.

import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/auth/data/models/user_model.dart';
import 'package:doon_walkers/features/auth/domain/entities/user_entity.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/admin_merch_inquiries_card.dart';
import 'package:doon_walkers/features/notifications/presentation/widgets/admin_send_notification_card.dart';
import 'package:doon_walkers/features/profile/presentation/widgets/leaderboard_visibility_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('Leaderboard visibility toggle', () {
    testWidgets('reflects showOnLeaderboard = true', (tester) async {
      await tester.pumpWidget(_host(
        const LeaderboardVisibilityToggle(),
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => Stream.value(_user(role: UserRole.user, showOnLeaderboard: true)),
          ),
        ],
      ));
      await tester.pump();
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
      expect(find.text('Show me on leaderboards'), findsOneWidget);
    });

    testWidgets('reflects showOnLeaderboard = false (opted out)', (tester) async {
      await tester.pumpWidget(_host(
        const LeaderboardVisibilityToggle(),
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => Stream.value(_user(role: UserRole.user, showOnLeaderboard: false)),
          ),
        ],
      ));
      await tester.pump();
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);
    });
  });
}
