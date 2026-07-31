import 'dart:async';

import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/router/app_router.dart';
import 'package:doon_walkers/features/notifications/data/repositories/device_token_repository_impl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Must be a top-level (or static) function — firebase_messaging's
/// requirement for `FirebaseMessaging.onBackgroundMessage`, since it
/// runs in a separate isolate when the app is backgrounded/terminated,
/// which can't capture instance state from [PushNotificationService].
/// Deliberately does almost nothing: the OS already shows the system
/// notification for a backgrounded/terminated app directly from the
/// FCM message's own `notification` payload — this handler exists only
/// because Firebase requires one to be registered. The foreground case
/// is the one that actually needs code, in
/// [PushNotificationService._showForegroundNotification], which runs
/// in the main isolate where flutter_local_notifications and Riverpod
/// state are reachable.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    'PushNotificationService: background message ${message.messageId}',
  );
}

/// Riverpod provider exposing [PushNotificationService].
final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(ref),
  name: 'pushNotificationServiceProvider',
);

/// FCM + local-notification plumbing: requests permission, keeps
/// `public.device_tokens` in sync with this device's current token
/// (including rotation), shows a heads-up notification while the app is
/// foregrounded (FCM alone only auto-displays a system notification
/// when backgrounded/terminated — a foregrounded app gets nothing for
/// free), and routes a tap from any app state to the in-app
/// notification list.
///
/// This phase is broadcast-only (see the Phase 8 brief's explicit scope
/// boundary), so every notification means the same thing regardless of
/// its content — there is no per-trek/per-registration deep link to
/// resolve, [AppConstants.routeNotifications] is always the right
/// destination for a tap.
class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;

  static const _androidChannel = AndroidNotificationChannel(
    'doon_walkers_broadcasts',
    'Community Announcements',
    description:
        'Trek updates, cancellations, and other community-wide announcements.',
    importance: Importance.high,
  );

  /// Celebration system (daily goal / streak / reminder notifications)
  /// — a separate channel from [_androidChannel] since it's a
  /// different kind of alert (the signed-in user's own activity, not
  /// a community broadcast) that a user may want to mute independently
  /// in system settings.
  static const _activityChannel = AndroidNotificationChannel(
    'doon_walkers_activity',
    'Activity & Streaks',
    description:
        'Daily goal, streak, and reminder notifications for your activity.',
    importance: Importance.high,
  );

  // Fixed ids so re-showing/re-scheduling replaces rather than
  // duplicates — flutter_local_notifications treats a `show`/
  // `zonedSchedule` call with an already-used id as a replacement, not
  // a second notification.
  static const _goalCompletedNotificationId = 2001;
  static const _streakNotificationId = 2002;
  static const _morningReminderId = 2003;
  static const _eveningReminderId = 2004;

  /// Local-notification taps carry this payload for every celebration-
  /// system notification (goal/streak/reminders) — they all want the
  /// same destination, the Activity tab, distinct from every other
  /// local/FCM notification's [_openNotifications] default.
  static const _activityPayload = 'activity';

  /// Call once at app startup, after `Firebase.initializeApp()` — sets
  /// up local notifications, requests permission, and wires every
  /// message/tap/refresh listener. Only ever called once from
  /// main.dart; not guarded against repeat calls since there's no
  /// legitimate reason to call it twice.
  Future<void> initialize() async {
    debugPrint('[Push] initialize() starting...');

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_androidChannel);
    await androidPlugin?.createNotificationChannel(_activityChannel);
    debugPrint(
      '[Push] local notification channels "${_androidChannel.id}" and '
      '"${_activityChannel.id}" created',
    );

    // Required for zonedSchedule (scheduleDailyReminders) — resolves
    // this device's IANA zone so TZDateTime computes "8:00 AM" in the
    // user's actual local time, not UTC. Best-effort: a failure here
    // just means the two reminders below won't be scheduled (caught in
    // their own call sites), not a startup crash.
    tz_data.initializeTimeZones();
    try {
      final locationName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(locationName));
      debugPrint('[Push] local timezone resolved: $locationName');
    } catch (e) {
      debugPrint('[Push] failed to resolve local timezone: $e');
    }

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      // Foreground local-notification tap (Android taps the heads-up
      // banner we posted ourselves in _showForegroundNotification, or
      // any of the celebration-system notifications below). Branches
      // on payload: the celebration system's own notifications all
      // carry [_activityPayload] and open the Activity tab instead of
      // the in-app notification list — there's no notification-list
      // row backing an ephemeral local reminder/celebration alert.
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == _activityPayload) {
          _ref.read(routerProvider).push(AppConstants.routeActivity);
          return;
        }
        _openNotifications();
      },
    );
    debugPrint('[Push] flutter_local_notifications initialized');

    // Required top-level handler registration — see its own doc for why
    // it stays minimal.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Triggers the Android 13+ POST_NOTIFICATIONS runtime permission
    // prompt; firebase_messaging handles that internally as of the
    // version pinned in pubspec.yaml.
    debugPrint('[Push] requesting notification permission...');
    final settings = await FirebaseMessaging.instance.requestPermission();
    debugPrint(
      '[Push] permission result: '
      'authorizationStatus=${settings.authorizationStatus}, '
      'alert=${settings.alert}, badge=${settings.badge}, sound=${settings.sound}',
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Backgrounded (not terminated), tapped to resume.
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _openNotifications());

    // Terminated, cold-started by tapping the notification — checked
    // once at startup, not a stream.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _openNotifications();

    // FCM tokens rotate (reinstall, data clear, periodic refresh) with
    // no error — a stale token just silently stops receiving pushes —
    // so this has to be a standing subscription, not a one-time read.
    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh
        .listen((token) async {
          debugPrint('[Push] onTokenRefresh fired: token=$token');
          if (Supabase.instance.client.auth.currentUser == null) {
            debugPrint(
              '[Push] onTokenRefresh: no signed-in user, skipping upsert',
            );
            return;
          }
          try {
            await _ref.read(deviceTokenRepositoryProvider).upsertToken(token);
            debugPrint('[Push] onTokenRefresh: token upserted successfully');
          } catch (e, st) {
            debugPrint('[Push] onTokenRefresh: upsert FAILED: $e');
            debugPrint('[Push] $st');
          }
        });

    debugPrint('[Push] initialize() complete');
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  void _openNotifications() {
    _ref.read(routerProvider).push(AppConstants.routeNotifications);
  }

  static String _withThousandsSeparator(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  AndroidNotificationDetails get _activityAndroidDetails =>
      AndroidNotificationDetails(
        _activityChannel.id,
        _activityChannel.name,
        channelDescription: _activityChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      );

  /// Part 1 of the celebration brief — shown by [ActivitySyncController]
  /// the moment a sync crosses today's step goal for the first time.
  /// Called at most once a day: the caller checks
  /// [CelebrationTracker.hasHappenedToday] first, this method itself
  /// has no duplicate-guard of its own.
  Future<void> showGoalCompletedNotification({required int steps}) async {
    await _localNotifications.show(
      _goalCompletedNotificationId,
      '🎉 Daily Goal Completed!',
      'You reached today\'s goal with '
          '${_withThousandsSeparator(steps)} steps.\nKeep moving!',
      NotificationDetails(android: _activityAndroidDetails),
      payload: _activityPayload,
    );
  }

  /// Part 3/5 — shown alongside the streak celebration when a sync
  /// grows the activity streak. Copy switches to the brief's "Amazing"
  /// framing at a week or more, per Part 5's weekly-streak example;
  /// below that it's a plainer "keep it going" nudge.
  Future<void> showStreakNotification({required int streakCount}) async {
    final isWeekOrMore = streakCount >= 7;
    await _localNotifications.show(
      _streakNotificationId,
      isWeekOrMore ? '🔥 Amazing!' : '🔥 Streak Alive!',
      isWeekOrMore
          ? "You've maintained a $streakCount-day streak."
          : '$streakCount Day Streak! Keep it going.',
      NotificationDetails(android: _activityAndroidDetails),
      payload: _activityPayload,
    );
  }

  tz.TZDateTime _nextInstanceOfLocalTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Part 5 — the two daily-repeating local reminders. Call once at
  /// app startup (see main.dart); fixed ids mean calling it again
  /// (e.g. every app launch) reschedules the same two notifications
  /// rather than accumulating duplicates.
  ///
  /// [AndroidScheduleMode.inexactAllowWhileIdle] deliberately, not
  /// `exactAllowWhileIdle`: an exact alarm needs the
  /// `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` runtime permission on
  /// Android 12+, a real user-facing settings trip that isn't
  /// justified for a nudge that's fine landing a few minutes off
  /// schedule.
  Future<void> scheduleDailyReminders({required int goal}) async {
    try {
      await _localNotifications.zonedSchedule(
        _morningReminderId,
        'Good morning!',
        'Ready to reach today\'s '
            '${_withThousandsSeparator(goal)}-step goal?',
        _nextInstanceOfLocalTime(8, 0),
        NotificationDetails(android: _activityAndroidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: _activityPayload,
      );

      // A placeholder evening reminder — rescheduleEveningReminder is
      // called after every successful sync and replaces this with the
      // actual remaining-steps figure (or cancels it outright if the
      // goal's already met). This just guarantees something is
      // scheduled for this evening even before the day's first sync.
      await _localNotifications.zonedSchedule(
        _eveningReminderId,
        'Still time today!',
        'Take a short walk to complete today\'s goal.',
        _nextInstanceOfLocalTime(19, 0),
        NotificationDetails(android: _activityAndroidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: _activityPayload,
      );
      debugPrint('[Push] daily reminders scheduled (8:00 AM / 7:00 PM local)');
    } catch (e) {
      debugPrint('[Push] scheduleDailyReminders failed: $e');
    }
  }

  /// Called after every successful sync (Part 5's "evening reminder
  /// only when the goal is incomplete") to keep today's evening
  /// reminder honest. Best-effort by nature — "local notifications, no
  /// backend" means this reflects steps as of the last sync, not a
  /// live background count; it cannot know about steps taken between
  /// that sync and the evening the notification would fire.
  Future<void> rescheduleEveningReminder({required int remainingSteps}) async {
    if (remainingSteps <= 0) {
      await _localNotifications.cancel(_eveningReminderId);
      return;
    }
    try {
      await _localNotifications.zonedSchedule(
        _eveningReminderId,
        'Only ${_withThousandsSeparator(remainingSteps)} steps left!',
        'Take a short walk to complete today\'s goal.',
        _nextInstanceOfLocalTime(19, 0),
        NotificationDetails(android: _activityAndroidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: _activityPayload,
      );
    } catch (e) {
      debugPrint('[Push] rescheduleEveningReminder failed: $e');
    }
  }

  /// Registers (upserts) this device's current FCM token for the
  /// signed-in user. Called on sign-in — see [pushTokenSyncProvider].
  Future<void> registerTokenForCurrentUser() async {
    debugPrint('[Push] registerTokenForCurrentUser() starting...');
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final now = DateTime.now();
      final expiresAt = session?.expiresAt;
      debugPrint(
        '[Push] currentSession at registration time: '
        'present=${session != null}, '
        'accessTokenLen=${session?.accessToken.length}, '
        'expiresAt=${expiresAt != null ? DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000) : null}, '
        'now=$now, '
        'isExpired=${session?.isExpired}',
      );

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('[Push] getToken() returned null — cannot register');
        return;
      }
      debugPrint('[Push] getToken() returned: $token');

      await _ref.read(deviceTokenRepositoryProvider).upsertToken(token);
      debugPrint('[Push] token upserted to device_tokens successfully');
    } catch (e, st) {
      debugPrint('[Push] registerTokenForCurrentUser() FAILED: $e');
      debugPrint('[Push] $st');
    }
  }

  /// Removes this device's token row. MUST be called BEFORE sign-out
  /// completes, not after — `device_tokens_delete_own`'s RLS check
  /// needs `auth.uid()` to still resolve to the signing-out user; once
  /// the session is actually cleared, this DELETE has no matching
  /// `auth.uid()` left to satisfy the policy and would silently fail.
  /// See AuthController.signOut for the call site.
  Future<void> removeTokenForCurrentUser() async {
    debugPrint('[Push] removeTokenForCurrentUser() starting...');
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      debugPrint('[Push] getToken() returned null — nothing to remove');
      return;
    }
    await _ref.read(deviceTokenRepositoryProvider).removeToken(token);
    debugPrint('[Push] token removed from device_tokens');
  }
}

/// Fire-and-forget side-effect provider: syncs `public.device_tokens`
/// with auth state for the app's whole lifetime. Watched once from
/// [DoonWalkersApp] so it initialises at startup and then just reacts;
/// nothing ever reads its (meaningless) value.
///
/// Handles `initialSession` (already signed in at cold start) and
/// `signedIn`/`tokenRefreshed` the same way — all three mean "there is
/// a live session, make sure this device's token is registered to it."
/// `signedOut` here is a safety-net only for events this provider
/// itself observes AFTER the fact (e.g. a session expiring server-side)
/// — the NORMAL user-initiated sign-out path removes the token
/// pre-emptively in AuthController.signOut, before this even fires,
/// since by the time `signedOut` reaches this listener the session (and
/// therefore `auth.uid()`) is already gone.
final pushTokenSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<AuthState>>(
    authStateChangesProvider,
    (previous, next) {
      final event = next.valueOrNull?.event;
      final hasUser = Supabase.instance.client.auth.currentUser != null;
      debugPrint(
        '[Push] pushTokenSyncProvider: authStateChanges event=$event, '
        'currentUser=${hasUser ? "present" : "null"}',
      );

      final service = ref.read(pushNotificationServiceProvider);
      switch (event) {
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          if (hasUser) {
            service.registerTokenForCurrentUser();
          }
        case AuthChangeEvent.signedOut:
          service.removeTokenForCurrentUser();
        default:
          break;
      }
    },
    // Without this, a session already restored from disk before this
    // listener attaches (e.g. currentUserProvider/isAdminProvider
    // subscribing to authStateChangesProvider earlier during initial
    // route resolution) means the `initialSession` event was already
    // consumed as this provider's cached "current" value by the time
    // ref.listen runs — plain ref.listen only fires on CHANGES after
    // it's registered, so that first event would silently never be
    // seen and a returning signed-in user's token would never
    // register. fireImmediately forces one synthetic call with
    // whatever the already-cached value is, closing that gap.
    fireImmediately: true,
  );
}, name: 'pushTokenSyncProvider');
