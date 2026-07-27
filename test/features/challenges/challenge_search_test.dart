// Explore's search/filter rules. These failures are quiet ones — a
// case-sensitive search or an over-eager filter renders as "no challenges
// exist" rather than as a visible bug — so the matching is a pure function
// with direct coverage rather than logic buried in a widget.

import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/services/challenge_search.dart';
import 'package:flutter_test/flutter_test.dart';

Challenge _challenge({
  required String id,
  required String title,
  String description = '',
  ChallengeMetric metric = ChallengeMetric.dailySteps,
  ChallengeTimeWindow timeWindow = ChallengeTimeWindow.daily,
  DateTime? endDate,
}) => Challenge(
  id: id,
  title: title,
  description: description,
  metric: metric,
  timeWindow: timeWindow,
  endDate: endDate,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

final _stepChallenge = _challenge(
  id: 'a',
  title: 'October Push',
  description: 'Rack up steps across the month.',
  metric: ChallengeMetric.monthlySteps,
);
final _distanceChallenge = _challenge(
  id: 'b',
  title: 'Valley Distance',
  description: 'Cover ground on foot.',
  metric: ChallengeMetric.dailyDistanceKm,
);
final _streakChallenge = _challenge(
  id: 'c',
  title: 'Never Miss a Day',
  metric: ChallengeMetric.activeStreakDays,
);
final _calorieChallenge = _challenge(
  id: 'd',
  title: 'Burn It',
  metric: ChallengeMetric.caloriesBurned,
);
final _trekChallenge = _challenge(
  id: 'e',
  title: 'Summit Seeker',
  metric: ChallengeMetric.trekCount,
);

final _all = [
  _stepChallenge,
  _distanceChallenge,
  _streakChallenge,
  _calorieChallenge,
  _trekChallenge,
];

List<String> _ids(List<Challenge> cs) => cs.map((c) => c.id).toList();

void main() {
  group('filterChallenges — search', () {
    test('an empty query returns everything, in input order', () {
      expect(_ids(filterChallenges(_all)), ['a', 'b', 'c', 'd', 'e']);
    });

    test('a whitespace-only query is treated as empty', () {
      expect(filterChallenges(_all, query: '   ').length, _all.length);
    });

    test('matches the title case-insensitively', () {
      expect(_ids(filterChallenges(_all, query: 'october')), ['a']);
      expect(_ids(filterChallenges(_all, query: 'OCTOBER')), ['a']);
    });

    test('matches the description too, not just the title', () {
      // Someone searching "steps" should find a challenge called "October
      // Push" whose description is what mentions steps.
      expect(_ids(filterChallenges(_all, query: 'steps')), ['a']);
    });

    test('matches a substring, not only a prefix', () {
      expect(_ids(filterChallenges(_all, query: 'alley')), ['b']);
    });

    test('a query matching nothing returns empty, not everything', () {
      expect(filterChallenges(_all, query: 'hydration'), isEmpty);
    });
  });

  group('filterChallenges — metric filters', () {
    test('no filters means no filtering, not "match nothing"', () {
      // This is the default state of the chip row, so getting it backwards
      // would show an empty Explore on first open.
      expect(filterChallenges(_all, metricFilters: const {}).length, 5);
    });

    test('the Steps filter covers all three step metrics', () {
      // daily/weekly/monthly steps all sum the same column and exist only
      // as admin vocabulary — one chip must catch all three.
      final challenges = [
        _challenge(id: '1', title: 'D', metric: ChallengeMetric.dailySteps),
        _challenge(id: '2', title: 'W', metric: ChallengeMetric.weeklySteps),
        _challenge(id: '3', title: 'M', metric: ChallengeMetric.monthlySteps),
        _distanceChallenge,
      ];
      expect(
        _ids(
          filterChallenges(
            challenges,
            metricFilters: const {ChallengeMetricFilter.steps},
          ),
        ),
        ['1', '2', '3'],
      );
    });

    test('the Distance filter covers both distance metrics', () {
      final challenges = [
        _distanceChallenge,
        _challenge(
          id: 'f',
          title: 'Total',
          metric: ChallengeMetric.totalDistanceKm,
        ),
        _stepChallenge,
      ];
      expect(
        _ids(
          filterChallenges(
            challenges,
            metricFilters: const {ChallengeMetricFilter.distance},
          ),
        ),
        ['b', 'f'],
      );
    });

    test('each remaining filter matches exactly its own metric', () {
      expect(
        _ids(
          filterChallenges(
            _all,
            metricFilters: const {ChallengeMetricFilter.streak},
          ),
        ),
        ['c'],
      );
      expect(
        _ids(
          filterChallenges(
            _all,
            metricFilters: const {ChallengeMetricFilter.calories},
          ),
        ),
        ['d'],
      );
      expect(
        _ids(
          filterChallenges(
            _all,
            metricFilters: const {ChallengeMetricFilter.trek},
          ),
        ),
        ['e'],
      );
    });

    test('multiple filters are OR-ed, not AND-ed', () {
      // A row of independently-toggleable chips implies OR; AND would make
      // any two selections return nothing, since a challenge has one
      // metric.
      expect(
        _ids(
          filterChallenges(
            _all,
            metricFilters: const {
              ChallengeMetricFilter.steps,
              ChallengeMetricFilter.streak,
            },
          ),
        ),
        ['a', 'c'],
      );
    });

    test('every real metric is reachable by some filter', () {
      // A challenge matching no chip would be invisible whenever any
      // filter is active. Guards against a metric being added to the enum
      // without a filter arm.
      for (final metric in ChallengeMetric.values) {
        expect(
          ChallengeMetricFilter.values.any((f) => f.matches(metric)),
          isTrue,
          reason: '$metric is not covered by any filter chip',
        );
      }
    });
  });

  group('filterChallenges — search and filters combined', () {
    test('both must pass', () {
      // "Push" matches challenge a, but a is a steps challenge — filtering
      // to Distance must exclude it.
      expect(
        filterChallenges(
          _all,
          query: 'Push',
          metricFilters: const {ChallengeMetricFilter.distance},
        ),
        isEmpty,
      );
      expect(
        _ids(
          filterChallenges(
            _all,
            query: 'Push',
            metricFilters: const {ChallengeMetricFilter.steps},
          ),
        ),
        ['a'],
      );
    });
  });

  group('filterChallenges — durationRange (Phase 24)', () {
    // All 5 fixtures above (_all) default to a `daily` time window —
    // their metric names (e.g. monthlySteps) describe what they SUM,
    // not how long the challenge itself runs — so duration tests build
    // their own fixtures with an explicit timeWindow instead of reusing
    // those.
    final monthLong = _challenge(
      id: 'm1',
      title: 'Month Long',
      timeWindow: ChallengeTimeWindow.monthly,
    );
    final dayLong = _challenge(
      id: 'd1',
      title: 'Today Only',
      timeWindow: ChallengeTimeWindow.daily,
      metric: ChallengeMetric.dailySteps,
    );
    final foreverOpen = _challenge(
      id: 'z1',
      title: 'Forever',
      timeWindow: ChallengeTimeWindow.allTime,
    );

    test('null durationRange means no duration filtering', () {
      expect(filterChallenges(_all, durationRange: null).length, 5);
    });

    test(
      'excludes a challenge whose derived duration falls outside the range',
      () {
        expect(
          _ids(
            filterChallenges(
              [monthLong, dayLong],
              durationRange: const ChallengeDurationRange(
                minDays: 1,
                maxDays: 7,
              ),
            ),
          ),
          ['d1'], // dayLong (1 day) passes; monthLong (30 days) does not
        );
      },
    );

    test(
      'a challenge with no derivable duration always passes the range filter',
      () {
        expect(
          _ids(
            filterChallenges(
              [foreverOpen],
              durationRange: const ChallengeDurationRange(
                minDays: 1,
                maxDays: 1,
              ),
            ),
          ),
          ['z1'],
        );
      },
    );

    test('a daily challenge (1 day) matches a 1-7 day range', () {
      expect(
        _ids(
          filterChallenges(
            [dayLong],
            durationRange: const ChallengeDurationRange(minDays: 1, maxDays: 7),
          ),
        ),
        ['d1'],
      );
    });

    test(
      'AND-composes with metric filters — matching the metric is not enough',
      () {
        // monthLong's metric defaults to dailySteps, so it passes the Steps
        // filter, but its 30-day window fails a 1-7 day range — both
        // conditions must hold.
        expect(
          _ids(
            filterChallenges(
              [dayLong, monthLong],
              metricFilters: const {ChallengeMetricFilter.steps},
              durationRange: const ChallengeDurationRange(
                minDays: 1,
                maxDays: 7,
              ),
            ),
          ),
          ['d1'],
        );
      },
    );
  });
}
