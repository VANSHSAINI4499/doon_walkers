import 'package:doon_walkers/core/config/env_config.dart';
import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:doon_walkers/core/router/app_router.dart';
import 'package:doon_walkers/core/services/push_notification_service.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return MaterialApp.router(
      title: 'Doon Walkers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
