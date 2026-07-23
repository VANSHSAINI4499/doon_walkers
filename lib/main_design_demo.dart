import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/design_demo/presentation/screens/design_system_demo_screen.dart';
import 'package:flutter/material.dart';

/// Isolated entrypoint for the Redesign Phase 1 component gallery.
///
/// Boots straight into [DesignSystemDemoScreen] with none of the app's
/// runtime bootstrap (Firebase, Supabase, push notifications, routing) —
/// so the foundation can be rendered and reviewed on its own, with no
/// credentials or network. Run with:
///
/// ```
/// flutter run -t lib/main_design_demo.dart
/// flutter build web -t lib/main_design_demo.dart --no-tree-shake-icons
/// ```
///
/// The real app entrypoint is `lib/main.dart`; this file is a review
/// harness only.
void main() {
  runApp(const _DesignDemoApp());
}

class _DesignDemoApp extends StatelessWidget {
  const _DesignDemoApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DoonWalkers · Design System',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.dark,
    home: const DesignSystemDemoScreen(),
  );
}
