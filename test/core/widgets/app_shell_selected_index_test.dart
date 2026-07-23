import 'package:doon_walkers/core/widgets/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

// Current branch layout (Version 2, Phase C2): 0 Home, 1 Treks,
// 2 Challenges, 3 Profile, 4 Trek Registrations (admin-only tab),
// 5 admin-only standalone screens (never a tab). So a guest/member has
// 4 destinations (0-3), an admin has 5 (0-4) — updated from the
// pre-Phase-C2 numbers (3/4) this file used to test, per explicit
// re-verification of the clamping logic for the new tab count.
void main() {
  group('resolveSelectedTabIndex', () {
    test('a normal in-range tab (e.g. Challenges) is trusted as-is', () {
      final (selected, next) = resolveSelectedTabIndex(
        currentIndex: 2,
        destinationsLength: 4,
        lastPrimaryIndex: 0,
      );
      expect(selected, 2);
      expect(next, 2);
    });

    test('the always-standalone admin screens branch (5) falls back '
        "to the last real tab, for both a guest/member's 4 tabs and an "
        "admin's 5", () {
      final asMember = resolveSelectedTabIndex(
        currentIndex: 5,
        destinationsLength: 4,
        lastPrimaryIndex: 1,
      );
      expect(asMember.$1, 1);

      final asAdmin = resolveSelectedTabIndex(
        currentIndex: 5,
        destinationsLength: 5,
        lastPrimaryIndex: 4,
      );
      expect(asAdmin.$1, 4);
    });

    test('an admin on the Trek Registrations tab (4) selects it normally', () {
      final (selected, next) = resolveSelectedTabIndex(
        currentIndex: 4,
        destinationsLength: 5,
        lastPrimaryIndex: 2,
      );
      expect(selected, 4);
      expect(next, 4);
    });

    test(
      'demotion while on Trek Registrations (4): once destinationsLength '
      'shrinks to 4, index 4 no longer exists — falls back to the last '
      'tab that still does, not an out-of-range selectedIndex',
      () {
        // Admin was on tab 4; a demotion mid-session shrinks this role's
        // tab count to 4 before the router has necessarily moved
        // currentIndex away yet — this is the exact race the crash
        // history is about, so currentIndex is deliberately still 4 here.
        final (selected, next) = resolveSelectedTabIndex(
          currentIndex: 4,
          destinationsLength: 4,
          lastPrimaryIndex: 1, // Treks — the last tab visited before this
        );
        expect(selected, 1);
        expect(next, 1);
        expect(selected, lessThan(4));
      },
    );

    test(
      'demotion while on Trek Registrations AND it was also the last '
      'known-good tab: falls all the way back to Home (0), never an '
      'out-of-range index',
      () {
        final (selected, next) = resolveSelectedTabIndex(
          currentIndex: 4,
          destinationsLength: 4,
          lastPrimaryIndex: 4,
        );
        expect(selected, 0);
        expect(next, 0);
      },
    );

    test(
      'promotion while on a shared tab (e.g. Profile): gaining the 5th '
      'tab does not disturb the current selection',
      () {
        final (selected, next) = resolveSelectedTabIndex(
          currentIndex: 3,
          destinationsLength: 5, // just promoted, now has 5 tabs
          lastPrimaryIndex: 3,
        );
        expect(selected, 3);
        expect(next, 3);
      },
    );

    test('selectedIndex is never >= destinationsLength, for any '
        'combination of currentIndex/lastPrimaryIndex', () {
      for (final destinationsLength in [4, 5]) {
        for (var currentIndex = 0; currentIndex <= 5; currentIndex++) {
          for (var lastPrimaryIndex = 0; lastPrimaryIndex <= 5; lastPrimaryIndex++) {
            final (selected, next) = resolveSelectedTabIndex(
              currentIndex: currentIndex,
              destinationsLength: destinationsLength,
              lastPrimaryIndex: lastPrimaryIndex,
            );
            expect(
              selected,
              lessThan(destinationsLength),
              reason: 'currentIndex=$currentIndex destinationsLength=$destinationsLength '
                  'lastPrimaryIndex=$lastPrimaryIndex produced selected=$selected',
            );
            expect(next, lessThan(destinationsLength));
          }
        }
      }
    });
  });
}
