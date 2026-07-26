import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';
import 'package:doon_walkers/features/notifications/domain/services/notification_grouping.dart';
import 'package:doon_walkers/features/notifications/presentation/providers/notification_providers.dart';
import 'package:doon_walkers/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-app notification list, grouped by day.
///
/// A plain top-level route (see `AppConstants.routeNotifications`), not
/// nested under any bottom-nav branch — reached via the bell in AppShell's
/// app bar (visible from every branch) or an FCM tap from any app state.
/// Guests are redirected to sign-in before reaching it.
///
/// ## Phase 13 scope, and one correction to the brief
///
/// The brief asked to "preserve the existing mark-as-read-on-open
/// behaviour and badge-count logic exactly (restyle only)". **Neither
/// existed.** Verified against the live schema: `public.notifications` is
/// `id, title, body, created_at, target_user_id` — no `read_at`, no
/// `notification_reads` table — and there was no badge or unread code
/// anywhere in `lib/`.
///
/// Since an Unread filter is meaningless without read state, and the phase
/// forbade backend changes, read state is device-local (see
/// `NotificationReadTracker`, which follows `ChallengeCelebrationTracker`'s
/// established precedent for exactly this situation). Opening this screen
/// marks everything currently in the list read, which is what clears the
/// bell badge.
///
/// ## What the query still does, untouched
///
/// The repository filters on `target_user_id` (own targeted rows plus every
/// broadcast) on top of RLS. Nothing in this file filters by recipient, and
/// the All/Unread control operates purely on read state.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// The ids that were unread when this screen opened.
  ///
  /// Captured once and held, because the rows are marked read a moment
  /// after arriving — without this snapshot every unread dot would vanish
  /// while the user was still looking at the list, and the Unread filter
  /// would empty itself the instant it was useful. The dots stay for this
  /// visit; the badge clears immediately.
  Set<String>? _unreadOnOpen;

  @override
  void initState() {
    super.initState();
    // After the first frame: the provider may still be loading, and
    // marking read touches providers, which cannot happen during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markVisibleRead());
  }

  Future<void> _markVisibleRead() async {
    final notifications = ref.read(notificationsProvider).valueOrNull;
    if (notifications == null || notifications.isEmpty) return;

    _unreadOnOpen ??= {
      for (final n in notifications)
        if (!ref.read(readNotificationIdsProvider).contains(n.id)) n.id,
    };

    await ref
        .read(notificationReadControllerProvider.notifier)
        .markRead(notifications.map((n) => n.id));
  }

  /// True if [item] was unread when this screen opened.
  bool _wasUnread(NotificationItem item) =>
      _unreadOnOpen?.contains(item.id) ?? false;

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final filter = ref.watch(notificationFilterProvider);

    // The list may resolve after initState's pass — mark read once it does.
    ref.listen(notificationsProvider, (previous, next) {
      if (next.hasValue) _markVisibleRead();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: notificationsAsync.when(
          loading: () => const _NotificationsSkeleton(),
          error: (error, stack) {
            debugPrint('NotificationsScreen: failed to load: $error');
            return _NotificationsError(
              onRetry: () => ref.invalidate(notificationsProvider),
            );
          },
          data: (notifications) {
            Future<void> onRefresh() =>
                ref.refresh(notificationsProvider.future);

            if (notifications.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    _NotificationsEmpty(
                      icon: AppIcons.notifications,
                      title: 'No notifications yet',
                      message:
                          'Community announcements and updates will show up '
                          'here.',
                    ),
                  ],
                ),
              );
            }

            final visible = filter == NotificationFilter.unread
                ? notifications.where(_wasUnread).toList()
                : notifications;

            final groups = groupNotificationsByDay(visible);

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  AppSegmentedControl<NotificationFilter>(
                    value: filter,
                    onChanged: (v) => ref
                        .read(notificationFilterProvider.notifier)
                        .state = v,
                    segments: [
                      for (final f in NotificationFilter.values) (f, f.label),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (visible.isEmpty)
                    const _NotificationsEmpty(
                      icon: AppIcons.taskDone,
                      title: 'All caught up',
                      message: "You've read everything here.",
                    )
                  else
                    for (final group in groups) ...[
                      _DayHeading(label: group.group.label),
                      for (final item in group.items) ...[
                        NotificationTile(
                          notification: item,
                          isUnread: _wasUnread(item),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.overline.copyWith(color: palette.textSecondary),
      ),
    );
  }
}

class _NotificationsEmpty extends StatelessWidget {
  const _NotificationsEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.huge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.cardHigh,
              shape: BoxShape.circle,
            ),
            child: AppIcon(icon, size: 30, color: palette.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: palette.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotificationsError extends StatelessWidget {
  const _NotificationsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.error, size: 40, color: palette.danger),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load notifications.',
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Retry',
              icon: AppIcons.refresh,
              variant: AppButtonVariant.glass,
              size: AppButtonSize.small,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SkeletonBox(height: 38, borderRadius: AppRadius.sm),
            const SizedBox(height: AppSpacing.xl),
            const SkeletonBox(width: 60, height: 11),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: palette.border),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(
                        width: 38,
                        height: 38,
                        borderRadius: AppRadius.sm,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 150, height: 14),
                            SizedBox(height: AppSpacing.sm),
                            SkeletonText(lines: 2, lineHeight: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
