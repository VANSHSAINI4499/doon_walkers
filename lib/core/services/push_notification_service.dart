import 'dart:async';

import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/router/app_router.dart';
import 'package:doon_walkers/features/notifications/data/repositories/device_token_repository_impl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  debugPrint('PushNotificationService: background message ${message.messageId}');
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
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;

  static const _androidChannel = AndroidNotificationChannel(
    'doon_walkers_broadcasts',
    'Community Announcements',
    description: 'Trek updates, cancellations, and other community-wide announcements.',
    importance: Importance.high,
  );

  /// Call once at app startup, after `Firebase.initializeApp()` — sets
  /// up local notifications, requests permission, and wires every
  /// message/tap/refresh listener. Only ever called once from
  /// main.dart; not guarded against repeat calls since there's no
  /// legitimate reason to call it twice.
  Future<void> initialize() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      // Foreground local-notification tap (Android taps the heads-up
      // banner we posted ourselves in _showForegroundNotification).
      onDidReceiveNotificationResponse: (_) => _openNotifications(),
    );

    // Required top-level handler registration — see its own doc for why
    // it stays minimal.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Triggers the Android 13+ POST_NOTIFICATIONS runtime permission
    // prompt; firebase_messaging handles that internally as of the
    // version pinned in pubspec.yaml.
    await FirebaseMessaging.instance.requestPermission();

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
    _tokenRefreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (Supabase.instance.client.auth.currentUser == null) return;
      await _ref.read(deviceTokenRepositoryProvider).upsertToken(token);
    });
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

  /// Registers (upserts) this device's current FCM token for the
  /// signed-in user. Called on sign-in — see [pushTokenSyncProvider].
  Future<void> registerTokenForCurrentUser() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _ref.read(deviceTokenRepositoryProvider).upsertToken(token);
  }

  /// Removes this device's token row. MUST be called BEFORE sign-out
  /// completes, not after — `device_tokens_delete_own`'s RLS check
  /// needs `auth.uid()` to still resolve to the signing-out user; once
  /// the session is actually cleared, this DELETE has no matching
  /// `auth.uid()` left to satisfy the policy and would silently fail.
  /// See AuthController.signOut for the call site.
  Future<void> removeTokenForCurrentUser() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await _ref.read(deviceTokenRepositoryProvider).removeToken(token);
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
final pushTokenSyncProvider = Provider<void>(
  (ref) {
    ref.listen<AsyncValue<AuthState>>(authStateChangesProvider, (previous, next) {
      final event = next.valueOrNull?.event;
      final service = ref.read(pushNotificationServiceProvider);
      switch (event) {
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          if (Supabase.instance.client.auth.currentUser != null) {
            service.registerTokenForCurrentUser();
          }
        case AuthChangeEvent.signedOut:
          service.removeTokenForCurrentUser();
        default:
          break;
      }
    });
  },
  name: 'pushTokenSyncProvider',
);
