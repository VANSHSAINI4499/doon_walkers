// Pure-function coverage for the bottom nav's selectedIndex clamping —
// the exact bug class this shell's crash history is about (an
// out-of-range selectedIndex reaching the nav bar and tripping its
// assertion).
//
// Branch layout after Redesign 2.0 Phase 18:
//   0 Home · 1 Activity · 2 Treks · 3 Community · 4 Profile
//   5 admin-only screens (NEVER a tab)
//
// The important change from the previous two layouts: **every role now
// has the same five tabs**. Admin's extra Trek Registrations tab is gone
// (it moved to the drawer), so the tab count is a compile-time constant
// that cannot shrink under a live role change. That structurally removes
// one of the two historical crash triggers; the remaining one is branch
// 5, which is not a tab at all.

import 'package:doon_walkers/core/widgets/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

/// Branches 0-4 are tabs; 5 is the admin-only branch.
const _tabCount = 5;
const _adminBranch = 5;

void main() {
  group('resolveSelectedTabIndex', () {
    test('an in-range tab is trusted as-is', () {
      for (var i = 0; i < _tabCount; i++) {
        final (selected, next) = resolveSelectedTabIndex(
          currentIndex: i,
          lastPrimaryIndex: 0,
        );
        expect(selected, i, reason: 'branch $i is a tab and should select');
        expect(next, i);
      }
    });

    test('the new Activity tab (branch 1) selects normally', () {
      // Guards the insertion specifically: Activity was added at index 1,
      // shifting Treks/Challenges/Profile up by one. If the branch order
      // and the destinations list ever disagree, this is where it shows.
      final (selected, next) = resolveSelectedTabIndex(
        currentIndex: 1,
        lastPrimaryIndex: 0,
      );
      expect(selected, 1);
      expect(next, 1);
    });

    test('Profile is now index 4, not 3', () {
      final (selected, _) = resolveSelectedTabIndex(
        currentIndex: 4,
        lastPrimaryIndex: 0,
      );
      expect(selected, 4);
    });

    test(
      'the admin-only branch (5) is never a tab — falls back to the last '
      'real tab instead of selecting itself',
      () {
        for (var last = 0; last < _tabCount; last++) {
          final (selected, next) = resolveSelectedTabIndex(
            currentIndex: _adminBranch,
            lastPrimaryIndex: last,
          );
          expect(selected, last);
          expect(next, last);
          expect(selected, lessThan(_tabCount));
        }
      },
    );

    test(
      'an admin opening Registrations from the drawer keeps whichever tab '
      'they were on highlighted',
      () {
        // The real Phase 10 scenario: admin is on Challenges (3), opens
        // the drawer, taps Registrations. The router moves to branch 5,
        // which has no tab — the bar should keep showing Challenges
        // rather than blanking or crashing.
        final (selected, next) = resolveSelectedTabIndex(
          currentIndex: _adminBranch,
          lastPrimaryIndex: 3,
        );
        expect(selected, 3);
        expect(next, 3);
      },
    );

    test('a demotion while on the admin branch cannot produce a bad index', () {
      // AppShell's ref.listen actively navigates Home on this transition,
      // but the clamp must hold on its own even if that fires a frame
      // late — that ordering is exactly what the original incident was.
      final (selected, next) = resolveSelectedTabIndex(
        currentIndex: _adminBranch,
        lastPrimaryIndex: 4,
      );
      expect(selected, 4);
      expect(next, 4);
      expect(selected, lessThan(_tabCount));
    });

    test('a nonsense lastPrimaryIndex falls all the way back to Home', () {
      // Defensive: unreachable in practice (lastPrimaryIndex starts at 0
      // and is only ever assigned values already proven in range), but
      // the fallback must not itself return something out of range.
      final (selected, next) = resolveSelectedTabIndex(
        currentIndex: _adminBranch,
        lastPrimaryIndex: 99,
      );
      expect(selected, 0);
      expect(next, 0);
    });

    test('negative indices are treated as invalid, not trusted', () {
      final (selected, next) = resolveSelectedTabIndex(
        currentIndex: -1,
        lastPrimaryIndex: -1,
      );
      expect(selected, 0);
      expect(next, 0);
    });

    test(
      'selectedIndex is never out of range for ANY combination of '
      'currentIndex and lastPrimaryIndex',
      () {
        // The invariant the crash history is really about. Swept wide on
        // purpose, including indices no real router would produce.
        for (var currentIndex = -2; currentIndex <= 8; currentIndex++) {
          for (var last = -2; last <= 8; last++) {
            final (selected, next) = resolveSelectedTabIndex(
              currentIndex: currentIndex,
              lastPrimaryIndex: last,
            );
            expect(
              selected,
              inInclusiveRange(0, _tabCount - 1),
              reason:
                  'currentIndex=$currentIndex lastPrimaryIndex=$last '
                  'produced selected=$selected',
            );
            expect(next, inInclusiveRange(0, _tabCount - 1));
          }
        }
      },
    );
  });
}
