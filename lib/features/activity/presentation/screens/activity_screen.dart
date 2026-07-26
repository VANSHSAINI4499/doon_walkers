import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/domain/repositories/activity_provider.dart';
import 'package:doon_walkers/features/activity/domain/services/activity_period.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_dashboard_providers.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_providers.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_period_navigator.dart';
import 'package:doon_walkers/features/activity/presentation/widgets/activity_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The Activity tab — the member's own movement dashboard.
///
/// Redesign 2.0 Phase 11 replaces Phase 10's placeholder with the real
/// Day / Week / Month views over `daily_activity_summary`.
///
/// ## What the reference asked for that isn't here, and why
///
///  - **Hour-by-hour Day chart.** There is no intraday data — one row per
///    day. A trailing seven-day chart takes that slot instead. See
///    [ActivityDayView]'s doc for the full trade.
///  - **Active-time tile.** `EXERCISE_TIME` is iOS-only in the `health`
///    package and there is no column for it. Omitted, not faked.
///  - **Recent Achievements.** The only tier history available
///    (`get_my_challenge_tier_history`) is trek-attendance-derived and
///    predates the fitness pivot, so it would show trek medals on a steps
///    screen. Left to Challenges.
///
/// Everything shown is a real column: `steps`, `distance_km`, `calories`,
/// plus the goal from `users.daily_step_goal` (0034).
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  ActivityGranularity _granularity = ActivityGranularity.day;
  late ActivityPeriod _period = ActivityPeriod.day(DateTime.now());

  /// Switching granularity re-anchors on the *current* period's start
  /// date, so moving Day→Week while looking at 12 March lands on the week
  /// containing 12 March rather than jumping back to today.
  void _setGranularity(ActivityGranularity granularity) {
    setState(() {
      _granularity = granularity;
      _period = ActivityPeriod.of(granularity, _period.from);
    });
  }

  Future<void> _refresh() async {
    await ref.read(activitySyncControllerProvider.notifier).sync();
    ref.invalidate(activityRangeProvider);
    ref.invalidate(trailingWeekProvider);
    ref.invalidate(activityPercentileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.insights),
            tooltip: 'Insights',
            onPressed: () => context.push(AppConstants.routeActivityInsights),
          ),
        ],
      ),
      body: SafeArea(
        // The router protects /activity, so a guest is bounced to sign-in
        // before reaching here. This guard is belt-and-braces for the case
        // where the session expires while the tab is already open.
        child: !isSignedIn
            ? const _SignInRequired()
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  children: [
                    const _SyncNotice(),
                    AppSegmentedControl<ActivityGranularity>(
                      value: _granularity,
                      onChanged: _setGranularity,
                      segments: [
                        for (final g in ActivityGranularity.values)
                          (g, g.label),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ActivityPeriodNavigator(
                      period: _period,
                      onChanged: (p) => setState(() => _period = p),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    switch (_granularity) {
                      ActivityGranularity.day => ActivityDayView(
                        period: _period,
                      ),
                      ActivityGranularity.week => ActivityWeekView(
                        period: _period,
                      ),
                      ActivityGranularity.month => ActivityMonthView(
                        period: _period,
                      ),
                    },
                  ],
                ),
              ),
      ),
    );
  }
}

/// Health-Connect-unavailable / permission-missing / never-synced notice.
///
/// Reuses the *messaging* of `ActivityPermissionBanner` (which lives on
/// Challenges) rather than the widget itself: this tab needs a slightly
/// different emphasis — on Challenges a missing sync means progress looks
/// stale, here it means the screen is empty — and embedding the Challenges
/// banner would have made its copy answer to two screens at once.
///
/// Renders nothing once permission is granted and something has synced, so
/// it costs no space in the normal case.
class _SyncNotice extends ConsumerWidget {
  const _SyncNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(activityAvailabilityProvider).valueOrNull;
    final permission = ref.watch(activityPermissionGrantedProvider);
    final lastSynced = ref.watch(lastActivitySyncProvider);

    // Don't flash a notice while the checks are still resolving.
    if (permission.isLoading || availability == null) {
      return const SizedBox.shrink();
    }

    if (availability == ActivityAvailability.unavailable) {
      return _Notice(
        icon: AppIcons.download,
        title: 'Health Connect required',
        message:
            'Install or update Health Connect to see your steps, distance '
            'and calories here.',
        actionLabel: 'Install',
        onAction: () =>
            ref.read(activityProviderProvider).openProviderSettings(),
      );
    }

    if (permission.valueOrNull != true) {
      return _Notice(
        icon: AppIcons.safety,
        title: 'Connect your activity',
        message:
            'Grant read-only access to your steps, distance and calories. '
            'Nothing is ever written back.',
        actionLabel: 'Grant access',
        onAction: () async {
          final granted = await ref
              .read(activityProviderProvider)
              .requestPermission();
          if (granted) {
            await ref.read(activitySyncControllerProvider.notifier).sync();
          }
          ref.invalidate(activityPermissionGrantedProvider);
        },
      );
    }

    // Permission granted but nothing has ever synced — distinct from the
    // above, and from a period that simply has no data in it.
    if (lastSynced.hasValue && lastSynced.value == null) {
      return const _Notice(
        icon: AppIcons.refresh,
        title: 'Nothing synced yet',
        message:
            'Pull down to sync your activity from Health Connect. It can '
            'take a moment the first time.',
      );
    }

    return const SizedBox.shrink();
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        borderColor: palette.primary.withValues(alpha: 0.4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(icon, size: 20, color: palette.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: actionLabel!,
                      size: AppButtonSize.small,
                      onPressed: onAction,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInRequired extends StatelessWidget {
  const _SignInRequired();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.lock, size: 32, color: palette.textSecondary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Sign in to see your activity',
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
