import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/notifications/domain/services/notification_grouping.dart';
import 'package:doon_walkers/features/notifications/presentation/providers/notification_providers.dart';
import 'package:doon_walkers/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Set<String> _optimisticReadIds = {};

  void _markAllAsRead() {
    setState(() {
      final notifications = ref.read(notificationsProvider).valueOrNull ?? [];
      _optimisticReadIds = notifications.map((n) => n.id).toSet();
    });
    ref.read(notificationReadControllerProvider.notifier).markAllRead();
  }

  void _markOneAsRead(String id) {
    setState(() {
      _optimisticReadIds = {..._optimisticReadIds, id};
    });
    ref.read(notificationReadControllerProvider.notifier).markRead(id);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final readIdsAsync = ref.watch(readNotificationIdsProvider);
    final filter = ref.watch(notificationFilterProvider);

    final serverReadIds = readIdsAsync.valueOrNull ?? const <String>{};
    final effectiveReadIds = {...serverReadIds, ..._optimisticReadIds};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: _markAllAsRead,
            icon: const AppIcon(AppIcons.checkCircle, size: 18),
            label: const Text('Mark all read'),
          ),
        ],
      ),
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
            Future<void> onRefresh() async {
              await Future.wait([
                ref.refresh(notificationsProvider.future),
                ref.refresh(readNotificationIdsProvider.future),
                ref.refresh(unreadNotificationCountProvider.future),
              ]);
            }

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
                          'Community announcements and trek updates will show up here.',
                    ),
                  ],
                ),
              );
            }

            final visible =
                notifications.where((item) {
                  final isUnread = !effectiveReadIds.contains(item.id);
                  switch (filter) {
                    case NotificationFilter.all:
                      return true;
                    case NotificationFilter.unread:
                      return isUnread;
                    case NotificationFilter.updates:
                      return item.isTargeted;
                    case NotificationFilter.announcements:
                      return !item.isTargeted;
                  }
                }).toList();

            final groups = groupNotificationsByDay(visible);

            final emptyTitle = switch (filter) {
              NotificationFilter.all => 'No notifications yet',
              NotificationFilter.unread => 'All caught up',
              NotificationFilter.updates => 'No trek updates',
              NotificationFilter.announcements => 'No announcements',
            };

            final emptyMessage = switch (filter) {
              NotificationFilter.all => 'Announcements will appear here.',
              NotificationFilter.unread => "You've read everything here.",
              NotificationFilter.updates =>
                'Targeted trek and booking updates will appear here.',
              NotificationFilter.announcements =>
                'Community broadcasts will appear here.',
            };

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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          NotificationFilter.values.map((f) {
                            final isSelected = filter == f;
                            return Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              child: ChoiceChip(
                                label: Text(f.label),
                                selected: isSelected,
                                onSelected:
                                    (_) =>
                                        ref
                                            .read(
                                              notificationFilterProvider
                                                  .notifier,
                                            )
                                            .state = f,
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (visible.isEmpty)
                    _NotificationsEmpty(
                      icon:
                          filter == NotificationFilter.unread
                              ? AppIcons.taskDone
                              : AppIcons.notifications,
                      title: emptyTitle,
                      message: emptyMessage,
                    )
                  else
                    for (final group in groups) ...[
                      _DayHeading(label: group.group.label),
                      for (final item in group.items) ...[
                        NotificationTile(
                          notification: item,
                          isUnread: !effectiveReadIds.contains(item.id),
                          onTap: () => _markOneAsRead(item.id),
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
