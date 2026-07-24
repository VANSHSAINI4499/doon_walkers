import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Isolated review harness for the Redesign Phase 7 App Shell chrome —
/// the floating bottom nav bar, the restyled drawer, and (most
/// importantly, given this project's crash history) a LIVE role-toggle
/// button that flips `isAdminProvider` while AppShell stays mounted, the
/// same way a real role change arrives via Supabase Realtime mid-session.
///
/// Uses a minimal GoRouter mirroring the real app's 6-branch shape
/// (`lib/core/router/app_router.dart`) with simple placeholder bodies —
/// this demo is about the SHELL CHROME, not the real screens, which are
/// explicitly out of scope for this phase.
///
/// ```
/// flutter run -t lib/main_shell_demo.dart
/// ```
final _demoIsAdmin = StateProvider<bool>((ref) => false);

void main() {
  runApp(
    ProviderScope(
      overrides: [
        isAdminProvider.overrideWith((ref) => ref.watch(_demoIsAdmin)),
      ],
      child: const _ShellDemoApp(),
    ),
  );
}

class _DemoScreen extends ConsumerWidget {
  const _DemoScreen({required this.label, required this.accent, required this.icon});

  final String label;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(_demoIsAdmin);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            glowColor: accent,
            child: Column(
              children: [
                AppIcon(icon, size: 40, color: accent),
                const SizedBox(height: AppSpacing.md),
                Text(label, style: AppTextStyles.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This tab\'s real content is out of scope for Phase 7 — '
                  'this placeholder just proves which branch is showing.',
                  style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            blurEnabled: false,
            glowColor: isAdmin ? AppColors.accent : AppColors.primary,
            child: Row(
              children: [
                AppIcon(
                  isAdmin ? AppIcons.medal : AppIcons.person,
                  color: isAdmin ? AppColors.accent : AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    isAdmin
                        ? 'Admin — 5th tab (Registrations) is live in the bar below.'
                        : 'Member — only 4 shared tabs in the bar below.',
                    style: AppTextStyles.titleSmall,
                  ),
                ),
                Switch(
                  value: isAdmin,
                  onChanged: (v) => ref.read(_demoIsAdmin.notifier).state = v,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Toggling this WHILE you stay on this exact tab is the live '
            'role-transition case — try it from the Registrations tab to '
            'see the demotion redirect fire.',
            style: AppTextStyles.secondary(AppTextStyles.bodySmall),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

GoRouter _buildDemoRouter() {
  return GoRouter(
    initialLocation: AppConstants.routeHome,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeHome,
                builder: (_, __) =>
                    const _DemoScreen(label: 'Home', accent: AppColors.primary, icon: AppIcons.home),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeTrekLibrary,
                builder: (_, __) =>
                    const _DemoScreen(label: 'Treks', accent: AppColors.secondary, icon: AppIcons.treks),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeChallenges,
                builder: (_, __) => const _DemoScreen(
                  label: 'Challenges',
                  accent: AppColors.gold,
                  icon: AppIcons.challenges,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeProfile,
                builder: (_, __) => const _DemoScreen(
                  label: 'Profile',
                  accent: AppColors.accent,
                  icon: AppIcons.profile,
                ),
              ),
            ],
          ),
          // Branch 4 — admin-only Trek Registrations TAB.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeAdminTrekRegistrations,
                builder: (_, __) => const _DemoScreen(
                  label: 'Registrations (admin-only tab)',
                  accent: AppColors.danger,
                  icon: AppIcons.registrations,
                ),
              ),
            ],
          ),
          // Branch 5 — admin-only standalone screens, never a tab.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeAdminRegistrations,
                builder: (_, __) => const _DemoScreen(
                  label: 'Admin-only standalone (never a tab)',
                  accent: AppColors.danger,
                  icon: AppIcons.error,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _ShellDemoApp extends StatelessWidget {
  const _ShellDemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DoonWalkers · Shell',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: _buildDemoRouter(),
    );
  }
}
