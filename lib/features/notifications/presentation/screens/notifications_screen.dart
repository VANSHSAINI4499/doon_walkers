import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/glass_states.dart';
import 'package:doon_walkers/features/notifications/presentation/providers/notification_providers.dart';
import 'package:doon_walkers/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-app notification list — every broadcast, newest first.
///
/// A plain top-level route (see AppConstants.routeNotifications' doc),
/// not nested under any bottom-nav branch — reached via the bell icon
/// in AppShell's AppBar (visible from every branch) or a notification
/// tap from any app state. Guests are redirected to sign-in before
/// reaching this screen at all (see app_router.dart's protected-routes
/// check) — `notifications_select` only allows authenticated readers
/// anyway.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: notificationsAsync.when(
          loading: () => const SkeletonTileList(),
          error: (error, stack) {
            debugPrint('NotificationsScreen: failed to load notifications: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(AppIcons.error, size: 40, color: AppColors.danger),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Could not load notifications.',
                        style: AppTextStyles.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PremiumButton(
                        label: 'Retry',
                        variant: PremiumButtonVariant.glass,
                        onPressed: () => ref.invalidate(notificationsProvider),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          data: (notifications) {
            Future<void> onRefresh() => ref.refresh(notificationsProvider.future);

            if (notifications.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: const [
                    GlassEmptyState(
                      icon: AppIcons.notifications,
                      message: 'No notifications yet — community announcements will show up here.',
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: notifications.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) => NotificationTile(notification: notifications[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}
