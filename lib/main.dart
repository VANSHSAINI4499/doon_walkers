import 'package:doon_walkers/core/config/env_config.dart';
import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:doon_walkers/core/router/app_router.dart';
import 'package:doon_walkers/core/services/push_notification_service.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/core/widgets/app_splash_screen.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load environment variables from the .env asset.
  await dotenv.load(fileName: '.env');
  EnvConfig.validate(); // warns if keys are missing — non-fatal in Phase 1

  // 2. Initialise Supabase only when credentials are present.
  //    In Phase 1 the .env may be empty; the client simply won't connect.
  if (EnvConfig.isConfigured) {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseAnonKey,
    );
  }

  // 2b. Initialise the MSG91 OTP Widget SDK once, same "only if
  //     configured" gating as Supabase above — phone verification is an
  //     optional feature, not a startup prerequisite. See
  //     PhoneVerificationRepositoryImpl for where these calls are used.
  if (EnvConfig.isPhoneWidgetConfigured) {
    OTPWidget.initializeWidget(EnvConfig.msg91WidgetId, EnvConfig.msg91WidgetTokenAuth);
  }

  // 3. Firebase must be initialised before any other Firebase plugin —
  //    reads android/app/google-services.json under the hood via the
  //    Gradle plugin wired in android/app/build.gradle.kts.
  debugPrint('[Push] Firebase.initializeApp() starting...');
  try {
    final app = await Firebase.initializeApp();
    debugPrint('[Push] Firebase.initializeApp() succeeded: '
        'name=${app.name}, projectId=${app.options.projectId}, '
        'appId=${app.options.appId}');
  } catch (e, st) {
    debugPrint('[Push] Firebase.initializeApp() FAILED: $e');
    debugPrint('[Push] $st');
    rethrow;
  }

  // 4. Wrap the widget tree in ProviderScope so every widget can access
  //    Riverpod providers via ref, THEN initialise push notifications —
  //    it needs a ProviderContainer to read/invalidate providers
  //    (device token upserts, router navigation on tap), so it can't
  //    run before runApp. SharedPreferences is resolved the same way
  //    (async, needed before any widget reads sharedPreferencesProvider)
  //    and supplied as an override rather than lazily inside the
  //    provider itself, since Provider bodies must be synchronous.
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  await container.read(pushNotificationServiceProvider).initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DoonWalkersApp(),
    ),
  );
}

/// Root widget for the DoonWalkers application.
class DoonWalkersApp extends ConsumerWidget {
  const DoonWalkersApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fire-and-forget for the app's whole lifetime — see its own doc.
    // `watch` (not `read`) so it's created here and Riverpod knows this
    // widget "owns" keeping it alive for as long as the app runs.
    ref.watch(pushTokenSyncProvider);
    // Covers the "sync on app launch" requirement (Version 2, Challenges
    // Module pivot) — "sync on resume" is a separate hook in AppShell,
    // since that needs WidgetsBindingObserver, not just an auth listener.
    ref.watch(activityLaunchSyncProvider);

    return MaterialApp.router(
      title: 'Doon Walkers',
      debugShowCheckedModeBanner: false,
      // Dark-only (Redesign Phase 1). Set as both light and dark slots
      // with `themeMode: dark` so the OS light/dark setting can never
      // pull the app into an unstyled light Material default — there is
      // no light variant of this design system.
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
      // Redesign Phase 7 — bridges the native platform splash into the
      // router's first screen with a brief branded moment instead of a
      // jarring cut. `builder` wraps whatever GoRouter already resolved
      // to, so the real content is fully built underneath the splash for
      // its entire duration; see SplashGate's doc for why nothing here
      // blocks on real async work.
      builder: (context, child) => SplashGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
