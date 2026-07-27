import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/widgets/app_shell.dart';
import 'package:doon_walkers/features/activity/presentation/screens/activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Isolated review harness for the **Redesign 2.0 Phase 10** navigation
/// shell — the five-tab bottom nav, the rebuilt drawer, and (most
/// importantly, given this project's crash history) a LIVE role toggle
/// that flips `isAdminProvider` while AppShell stays mounted, the same
/// way a real role change arrives via Supabase Realtime mid-session.
///
/// Mirrors the real app's 6-branch shape
/// (`lib/core/router/app_router.dart`) with placeholder bodies, except
/// Activity, which renders the real [ActivityScreen] placeholder so the
/// new tab can be reviewed as it will actually ship.
///
/// ```
/// flutter run -t lib/main_shell_demo.dart
/// ```
///
/// What to exercise here:
///  - all five tabs navigate, in light and dark;
///  - the drawer's Admin section appears only with the toggle on;
///  - flipping the toggle *while on the admin branch* fires the
///    demotion redirect to Home;
///  - flipping it anywhere else leaves you exactly where you are, and
///    the tab bar never changes shape (it is role-independent now).
final _demoIsAdmin = StateProvider<bool>((ref) => false);

/// Lets the harness be reviewed in both themes without touching the OS
/// setting — the shell is chrome, so "does it hold up in light mode" is
/// a question about every screen in the app at once.
final _demoThemeMode = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

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

/// A placeholder tab body that also carries the role toggle, so the live
/// transition can be triggered from whichever branch is on screen.
class _DemoScreen extends ConsumerWidget {
  const _DemoScreen({
    required this.label,
    required this.icon,
    this.isAdminBranch = false,
  });

  final String label;
  final IconData icon;

  /// True on the admin screen, where the copy explains that the real
  /// app's `redirect` guard — not the shell — is what bounces a demoted
  /// admin. This harness has no redirect, so nothing happens here.
  final bool isAdminBranch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final isAdmin = ref.watch(_demoIsAdmin);
    final isDark = ref.watch(_demoThemeMode) == ThemeMode.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              children: [
                AppIcon(icon, size: 36, color: palette.primary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  label,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: palette.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "This tab's real content is out of scope for Phase 10 — "
                  'the placeholder just proves which branch is showing.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            borderColor:
                isAdmin ? palette.primary.withValues(alpha: 0.55) : null,
            child: Row(
              children: [
                AppIcon(
                  isAdmin ? AppIcons.medal : AppIcons.profile,
                  color: isAdmin ? palette.primary : palette.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    isAdmin
                        ? 'Admin — same five tabs, plus the drawer Admin section.'
                        : 'Member — five tabs, no Admin section in the drawer.',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: palette.textPrimary,
                    ),
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
          AppCard(
            child: Row(
              children: [
                AppIcon(
                  isDark ? AppIcons.themeDark : AppIcons.themeLight,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    isDark ? 'Dark theme' : 'Light theme',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                Switch(
                  value: isDark,
                  onChanged:
                      (v) =>
                          ref.read(_demoThemeMode.notifier).state =
                              v ? ThemeMode.dark : ThemeMode.light,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isAdminBranch
                ? 'This is a top-level route, pushed over the shell — note '
                    'there is no bottom nav. In the real app the router\'s '
                    'redirect guard bounces you Home on a demotion; this '
                    'harness has no redirect, so nothing happens here.'
                : 'Toggling this while you stay on this tab is the live '
                    'role-transition case. The bar must not change shape.',
            style: AppTextStyles.bodySmall.copyWith(
              color: palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Mirrors app_router.dart's branch order exactly:
/// 0 Home · 1 Activity · 2 Treks · 3 Challenges · 4 Profile · 5 admin.
GoRouter _buildDemoRouter() {
  return GoRouter(
    initialLocation: AppConstants.routeHome,
    routes: [
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeHome,
                builder:
                    (_, _) =>
                        const _DemoScreen(label: 'Home', icon: AppIcons.home),
              ),
            ],
          ),
          // Branch 1 — the real Activity placeholder, so the new tab is
          // reviewed as it will actually ship rather than as a stand-in.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeActivity,
                builder: (_, _) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeTrekLibrary,
                builder:
                    (_, _) =>
                        const _DemoScreen(label: 'Treks', icon: AppIcons.treks),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeChallenges,
                builder:
                    (_, _) => const _DemoScreen(
                      label: 'Challenges',
                      icon: AppIcons.challenges,
                    ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeProfile,
                builder:
                    (_, _) => const _DemoScreen(
                      label: 'Profile',
                      icon: AppIcons.profile,
                    ),
              ),
            ],
          ),
        ],
      ),
      // Admin screens are TOP-LEVEL, outside the shell — matching the
      // real router. They were a branch until Phase 10, which was wrong
      // once the drawer became their entry point: the drawer pushes, and
      // push does not switch branches, so the shell stayed on whatever
      // tab was underneath.
      GoRoute(
        path: AppConstants.routeAdminTrekRegistrations,
        builder:
            (_, _) => const _DemoScreen(
              label: 'Registrations (drawer only)',
              icon: AppIcons.registrations,
              isAdminBranch: true,
            ),
      ),
      // The drawer's non-admin destinations, so tapping them in the demo
      // lands somewhere real rather than throwing a router error.
      for (final (path, label) in const [
        (AppConstants.routeMerchandise, 'Merchandise'),
        (AppConstants.routeAbout, 'About'),
        (AppConstants.routeSupport, 'Support'),
        (AppConstants.routeSettings, 'Settings'),
        (AppConstants.routeContact, 'Contact'),
        (AppConstants.routeAdminMerchInquiries, 'Merchandise Inquiries'),
        (AppConstants.routeAdminSendNotification, 'Send Notification'),
        (AppConstants.routeNotifications, 'Notifications'),
      ])
        GoRoute(
          path: path,
          builder:
              (context, state) => Scaffold(
                appBar: AppBar(title: Text(label)),
                body: Center(
                  child: Text(
                    '$label\n(real screen out of scope for this harness)',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppPalette.of(context).textSecondary,
                    ),
                  ),
                ),
              ),
        ),
    ],
  );
}

class _ShellDemoApp extends ConsumerStatefulWidget {
  const _ShellDemoApp();

  @override
  ConsumerState<_ShellDemoApp> createState() => _ShellDemoAppState();
}

class _ShellDemoAppState extends ConsumerState<_ShellDemoApp> {
  // Built once and held: rebuilding the router on every theme change
  // would reset the whole navigation stack mid-review.
  late final _router = _buildDemoRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DoonWalkers · Shell',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(_demoThemeMode),
      routerConfig: _router,
    );
  }
}
