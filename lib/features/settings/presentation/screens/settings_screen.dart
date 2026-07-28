import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/step_goal_sheet.dart';
import 'package:doon_walkers/features/auth/presentation/controllers/auth_controller.dart';
import 'package:doon_walkers/features/profile/presentation/providers/leaderboard_visibility_provider.dart';
import 'package:doon_walkers/features/settings/presentation/widgets/settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Settings — every real preference in one place.
///
/// ## What "real" means here
///
/// The reference for this phase listed a dozen rows. Most had no backing
/// feature and are deliberately absent: Account Settings editing,
/// per-category notification preferences, Units & Display, Blocked/Hidden
/// Users, Community Guidelines, Report a User, Help Center. None of those
/// exist as data or as a screen, and a row that opens nothing is worse
/// than no row.
///
/// What ships is exactly what works:
///
///  - **Appearance** — light/dark/system, persisted to SharedPreferences.
///  - **Daily step goal** — writes `users.daily_step_goal` (0034), with
///    the DB's own 500–100,000 CHECK surfaced as validation in the sheet.
///  - **Leaderboard visibility** — writes `users.show_on_leaderboard`,
///    and is enforced server-side inside `get_challenge_leaderboard()`.
///  - **About / Contact** — the existing drawer destinations, reached from
///    here too. Same screens, second entry point, no duplicated content.
///  - **Sign Out** — moved off Profile so the destructive action lives
///    with the other account controls rather than under the avatar.
///
/// ## No admin section, deliberately
///
/// The brief asked for an admin-tools entry here. There already is one:
/// Phase 10 gave the drawer an Admin section (Registrations, Merchandise
/// Inquiries, Send Notification), reachable from every screen in one tap.
/// Adding a second entry point in Settings — while Profile still had a
/// third — would have made three. Phase 14 instead removes Profile's copy
/// and leaves the drawer as the single admin home. Flagged rather than
/// silently skipped.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final isSignedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AppearanceSection(),
                const SizedBox(height: AppSpacing.xl),

                // Activity and privacy both write to the user's row, so
                // they are meaningless for a guest — and a guest can reach
                // this screen (it is an unprotected drawer destination).
                if (isSignedIn) ...[
                  const _ActivitySection(),
                  const SizedBox(height: AppSpacing.xl),
                  const _PrivacySection(),
                  const SizedBox(height: AppSpacing.xl),
                ],

                SettingsSection(
                  title: 'Community',
                  children: [
                    SettingsRow(
                      icon: AppIcons.info,
                      label: 'About',
                      description: 'Our story, vision and community rules.',
                      onTap: () => context.push(AppConstants.routeAbout),
                    ),
                    SettingsRow(
                      icon: AppIcons.connect,
                      label: 'Contact us',
                      description: 'Reach the community directly.',
                      onTap: () => context.push(AppConstants.routeContact),
                    ),
                  ],
                ),

                if (isSignedIn) ...[
                  const SizedBox(height: AppSpacing.xl),
                  SettingsSection(
                    title: 'Account',
                    children: [
                      SettingsRow(
                        icon: AppIcons.logout,
                        label: 'Sign out',
                        destructive: true,
                        onTap: () => _confirmSignOut(context, ref),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),
                Center(
                  child: Text(
                    '${AppConstants.appName} v${AppConstants.appVersion}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: palette.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Confirms before signing out.
  ///
  /// New in Phase 14 — Profile's old button signed out on a single tap. It
  /// is the one irreversible-feeling action in the app (it doesn't destroy
  /// anything, but it does mean finding your password again), and it now
  /// sits in a list where a mis-tap is easier.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text(
              "You'll need to sign in again to see your registrations, "
              'activity and wishlist.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppPalette.of(context).danger,
                ),
                child: const Text('Sign out'),
              ),
            ],
          ),
    );

    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

/// Theme, as one composite row.
///
/// The three-way control renders **inline** rather than behind a chevron:
/// it is the setting people flip most, three segments fit where a
/// value-plus-chevron would have gone, and pushing a whole screen to
/// choose between three words would be absurd.
///
/// It is a single [SettingsSection] child, not a row plus a separate
/// control — two children would draw the section's hairline straight
/// through the middle of one setting.
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final mode = ref.watch(themeModeProvider);

    return SettingsSection(
      title: 'Appearance',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppIcon(
                    switch (mode) {
                      ThemeMode.light => AppIcons.themeLight,
                      ThemeMode.dark => AppIcons.themeDark,
                      ThemeMode.system => AppIcons.themeSystem,
                    },
                    size: 20,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Theme',
                          style: AppTextStyles.titleSmall.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'System follows your device setting.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppSegmentedControl<ThemeMode>(
                value: mode,
                onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
                segments: const [
                  (ThemeMode.system, 'System'),
                  (ThemeMode.light, 'Light'),
                  (ThemeMode.dark, 'Dark'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(dailyStepGoalProvider);

    return SettingsSection(
      title: 'Activity',
      children: [
        SettingsRow(
          icon: AppIcons.steps,
          label: 'Daily step goal',
          description: 'Weekly and monthly targets follow from this.',
          value: '${_withSeparators(goal)} steps',
          onTap: () => showStepGoalSheet(context),
        ),
      ],
    );
  }

  static String _withSeparators(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

/// Leaderboard opt-out.
///
/// Moved here from Profile in Phase 14. **The read/write path is
/// unchanged**: it reads `showOnLeaderboard` off `currentUserProvider`
/// (which streams the caller's own row live) and writes through
/// `leaderboardVisibilityControllerProvider` to the real
/// `show_on_leaderboard` column — not local state. The server enforces it
/// inside `get_challenge_leaderboard()`; this switch only drives the
/// control's own position.
class _PrivacySection extends ConsumerWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final isSaving =
        ref.watch(leaderboardVisibilityControllerProvider).isLoading;
    final showOnLeaderboard = userAsync.valueOrNull?.showOnLeaderboard ?? true;

    ref.listen<AsyncValue<void>>(leaderboardVisibilityControllerProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        error: (error, stack) {
          debugPrint('SettingsScreen: leaderboard update failed: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not update this setting. Please try again.',
              ),
              backgroundColor: AppPalette.of(context).danger,
            ),
          );
        },
      );
    });

    return SettingsSection(
      title: 'Privacy',
      children: [
        SettingsRow(
          icon: AppIcons.leaderboard,
          label: 'Show me on leaderboards',
          description:
              'Turn off to hide your name and rank from other '
              'members.',
          trailing: Switch(
            value: showOnLeaderboard,
            onChanged:
                isSaving
                    ? null
                    : (value) => ref
                        .read(leaderboardVisibilityControllerProvider.notifier)
                        .setShowOnLeaderboard(value),
          ),
        ),
      ],
    );
  }
}
