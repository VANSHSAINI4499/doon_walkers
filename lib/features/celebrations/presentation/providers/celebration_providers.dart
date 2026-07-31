import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:doon_walkers/core/services/push_notification_service.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/celebrations/data/services/celebration_tracker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod provider exposing [CelebrationTracker] — same shape as
/// `challengeCelebrationTrackerProvider` (challenge_providers.dart).
final celebrationTrackerProvider = Provider<CelebrationTracker>(
  (ref) => CelebrationTracker(ref.watch(sharedPreferencesProvider)),
  name: 'celebrationTrackerProvider',
);

/// Fire-and-forget side-effect provider: (re)schedules the two daily
/// reminders (Part 5) whenever the signed-in user's current step goal
/// becomes known or changes — watched once from [DoonWalkersApp], same
/// pattern as `activityLaunchSyncProvider`.
///
/// Reacting to [dailyStepGoalProvider] rather than a single call at
/// startup solves two problems with one mechanism: [currentUserProvider]
/// (which [dailyStepGoalProvider] reads) may not have resolved yet at
/// the exact moment `main()` runs, and the user can change their goal
/// later from Settings — both cases are just another emission of the
/// same provider, so `fireImmediately: true` plus Riverpod's normal
/// reactivity covers both without a second call site.
final activityReminderScheduleProvider = Provider<void>((ref) {
  ref.listen<int>(dailyStepGoalProvider, (previous, goal) {
    ref.read(pushNotificationServiceProvider).scheduleDailyReminders(goal: goal);
  }, fireImmediately: true);
}, name: 'activityReminderScheduleProvider');
