import 'package:doon_walkers/core/config/env_config.dart';
import 'package:doon_walkers/core/router/app_router.dart';
import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      anonKey: EnvConfig.supabaseAnonKey, // ignore: deprecated_member_use
    );
  }

  // 3. Wrap the widget tree in ProviderScope so every widget can access
  //    Riverpod providers via ref.
  runApp(const ProviderScope(child: DoonWalkersApp()));
}

/// Root widget for the DoonWalkers application.
class DoonWalkersApp extends StatelessWidget {
  const DoonWalkersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Doon Walkers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
