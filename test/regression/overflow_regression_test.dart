// RenderFlex overflow regression coverage for the four screens fixed in
// this pass (Login, Home's Community Top 3, the Leaderboard podium, and
// Member Profile). Each is pumped at every required screen width
// (320/360/393/412/480dp) and text-scale factor (1.0-2.0x, since the
// original bugs were width- and/or scale-dependent — several only
// reproduced once BOTH a narrow width AND a larger accessibility text
// size were present at the same time). A failure here means a real
// RenderFlex overflow was thrown during layout, not a value mismatch.
//
// Screen width is set via `tester.view.physicalSize`, not a wrapping
// MediaQuery — MaterialApp/Scaffold size themselves to the actual test
// render surface, which a manually-supplied MediaQueryData does not
// change on its own.

import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:doon_walkers/features/community/domain/entities/community_leaderboard_entry.dart';
import 'package:doon_walkers/features/community/domain/entities/member_directory_entry.dart';
import 'package:doon_walkers/features/community/presentation/screens/member_profile_screen.dart';
import 'package:doon_walkers/features/community/presentation/widgets/community_podium.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _widths = [320.0, 360.0, 393.0, 412.0, 480.0];
const _scales = [1.0, 1.3, 1.6, 2.0];

void _setTestScreenSize(WidgetTester tester, double width, double height) {
  tester.view.physicalSize =
      Size(width, height) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
}

/// Fails the test with a clear message if layout threw a RenderFlex (or
/// any other) overflow exception during the last pump.
void _expectNoOverflow(WidgetTester tester, String label) {
  final exception = tester.takeException();
  expect(exception, isNull, reason: 'RenderFlex overflow in $label: $exception');
}

void main() {
  group('SignInScreen', () {
    for (final width in _widths) {
      for (final scale in _scales) {
        testWidgets('no overflow at ${width}dp scale $scale', (tester) async {
          _setTestScreenSize(tester, width, 900);
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: const ProviderScope(
                child: MaterialApp(home: SignInScreen()),
              ),
            ),
          );
          await tester.pump();
          _expectNoOverflow(tester, 'SignInScreen (${width}dp, scale $scale)');
        });
      }
    }
  });

  group('CommunityPodium (Leaderboard)', () {
    final entries = [
      const CommunityLeaderboardEntry(
        userId: '1',
        displayName: 'Alexandria Constantinopoulos',
        avatarUrl: null,
        totalPoints: 128450,
        level: 8,
        rank: 1,
      ),
      const CommunityLeaderboardEntry(
        userId: '2',
        displayName: 'Christopher Wolstenholme-Smith',
        avatarUrl: null,
        totalPoints: 98230,
        level: 7,
        rank: 2,
      ),
      const CommunityLeaderboardEntry(
        userId: '3',
        displayName: 'Priyamvada Ramachandran',
        avatarUrl: null,
        totalPoints: 76100,
        level: 6,
        rank: 3,
      ),
    ];

    for (final width in _widths) {
      for (final scale in _scales) {
        testWidgets('no overflow at ${width}dp scale $scale', (tester) async {
          _setTestScreenSize(tester, width, 800);
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                theme: AppTheme.dark,
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CommunityPodium(entries: entries),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 700));
          _expectNoOverflow(tester, 'CommunityPodium (${width}dp, scale $scale)');
        });
      }
    }
  });

  group('MemberProfileScreen (viewing another member)', () {
    final privateMember = MemberDirectoryEntry(
      userId: 'other-user',
      displayName: 'Priyamvada Ramachandran',
      avatarUrl: null,
      totalPoints: 45900,
      level: 6,
      createdAt: DateTime(2025, 3, 1),
    );

    for (final width in _widths) {
      for (final scale in _scales) {
        testWidgets('no overflow at ${width}dp scale $scale', (tester) async {
          _setTestScreenSize(tester, width, 900);
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: ProviderScope(
                overrides: [
                  currentUserIdProvider.overrideWithValue('someone-else'),
                ],
                child: MaterialApp(
                  theme: AppTheme.dark,
                  home: MemberProfileScreen(member: privateMember),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 700));
          _expectNoOverflow(
            tester,
            'MemberProfileScreen (${width}dp, scale $scale)',
          );
        });
      }
    }
  });
}
