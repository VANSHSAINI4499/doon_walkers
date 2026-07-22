import 'package:doon_walkers/core/widgets/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveSelectedTabIndex', () {
    test('a normal in-range tab (e.g. Treks) is trusted as-is', () {
      final (selected, next) = resolveSelectedTabIndex(
        currentIndex: 1,
        destinationsLength: 3,
        lastPrimaryIndex: 0,
      );
      expect(selected, 1);
      expect(next, 1);
    });

    test('the always-drawer-only Admin Dashboard branch (4) falls back '
        "to the last real tab, for both a guest/member's 3 tabs and an "
        "admin's 4", () {
      final asMember = resolveSelectedTabIndex(
        currentIndex: 4,
        destinationsLength: 3,
        lastPrimaryIndex: 1,
      );
      expect(asMember.$1, 1);

      final asAdmin = resolveSelectedTabIndex(
        currentIndex: 4,
        destinationsLength: 4,
        lastPrimaryIndex: 3,
      );
      expect(asAdmin.$1, 3);
    });

    test('an admin on the Trek Registrations tab (3) selects it normally', () {
      final (selected, next) = resolveSelectedTabIndex(
        currentIndex: 3,
        destinationsLength: 4,
        lastPrimaryIndex: 2,
      );
      expect(selected, 3);
      expect(next, 3);
    });

    test(
      'demotion while on Trek Registrations (3): once destinationsLength '
      'shrinks to 3, index 3 no longer exists — falls back to the last '
      'tab that still does, not an out-of-range selectedIndex',
      () {
        // Admin was on tab 3; a demotion mid-session shrinks this role's
        // tab count to 3 before the router has necessarily moved
        // currentIndex away yet — this is the exact race the crash
        // history is about, so currentIndex is deliberately still 3 here.
        final (selected, next) = resolveSelectedTabIndex(
          currentIndex: 3,
          destinationsLength: 3,
          lastPrimaryIndex: 1, // Treks — the last tab visited before this
        );
        expect(selected, 1);
        expect(next, 1);
        expect(selected, lessThan(3));
      },
    );

    test(
      'demotion while on Trek Registrations AND it was also the last '
      'known-good tab: falls all the way back to Home (0), never an '
      'out-of-range index',
      () {
        final (selected, next) = resolveSelectedTabIndex(
          currentIndex: 3,
          destinationsLength: 3,
          lastPrimaryIndex: 3,
        );
        expect(selected, 0);
        expect(next, 0);
      },
    );

    test(
      'promotion while on a shared tab (e.g. Profile): gaining the 4th '
      'tab does not disturb the current selection',
      () {
        final (selected, next) = resolveSelectedTabIndex(
          currentIndex: 2,
          destinationsLength: 4, // just promoted, now has 4 tabs
          lastPrimaryIndex: 2,
        );
        expect(selected, 2);
        expect(next, 2);
      },
    );

    test('selectedIndex is never >= destinationsLength, for any '
        'combination of currentIndex/lastPrimaryIndex', () {
      for (final destinationsLength in [3, 4]) {
        for (var currentIndex = 0; currentIndex <= 4; currentIndex++) {
          for (var lastPrimaryIndex = 0; lastPrimaryIndex <= 4; lastPrimaryIndex++) {
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
