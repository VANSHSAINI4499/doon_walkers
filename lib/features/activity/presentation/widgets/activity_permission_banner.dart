import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/domain/repositories/activity_provider.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fitness-sync status banner shown at the top of the Challenges tab — the
/// graceful-degradation surface the Challenges Module pivot asked for: a
/// device without Health Connect sees a clear explanation and a path
/// forward, never a broken feature or a crash.
///
/// Hidden entirely for guests (nothing to sync to). Redesign Phase 4
/// restyles it onto the design system (a glass banner with a gradient icon
/// tile and a [PremiumButton] action) — every availability/permission/sync
/// state and every action it fires is unchanged.
class ActivityPermissionBanner extends ConsumerWidget {
  const ActivityPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    if (!isSignedIn) return const SizedBox.shrink();

    final availabilityAsync = ref.watch(activityAvailabilityProvider);
    final permissionAsync = ref.watch(activityPermissionGrantedProvider);
    final lastSyncedAsync = ref.watch(lastActivitySyncProvider);
    final syncState = ref.watch(activitySyncControllerProvider);

    // Still resolving either check — render nothing rather than a flash of
    // "unavailable" that immediately flips to something else.
    if (availabilityAsync.isLoading || permissionAsync.isLoading) {
      return const SizedBox.shrink();
    }

    final availability = availabilityAsync.valueOrNull;
    final hasPermission = permissionAsync.valueOrNull ?? false;

    if (availability == ActivityAvailability.unavailable) {
      return _Banner(
        icon: AppIcons.download,
        accent: AppColors.accent,
        title: 'Health Connect required',
        message: 'Install or update Health Connect to track fitness challenges '
            '(steps, distance, calories).',
        actionLabel: 'Install',
        onAction: () => ref.read(activityProviderProvider).openProviderSettings(),
      );
    }

    if (!hasPermission) {
      return _Banner(
        icon: AppIcons.safety,
        accent: AppColors.primary,
        title: 'Sync your activity',
        message: 'Grant read-only access to your steps, distance, and calories to '
            'track fitness challenges. Nothing is ever written back.',
        actionLabel: 'Grant Access',
        isLoading: syncState.isLoading,
        onAction: () async {
          final granted = await ref.read(activityProviderProvider).requestPermission();
          if (granted) {
            await ref.read(activitySyncControllerProvider.notifier).sync();
          }
          ref.invalidate(activityPermissionGrantedProvider);
        },
      );
    }

    final lastSynced = lastSyncedAsync.valueOrNull;
    return _Banner(
      icon: AppIcons.sync,
      accent: AppColors.secondary,
      title: 'Activity synced',
      message: lastSynced == null
          ? 'Tap Sync Now to pull in your latest activity.'
          : 'Last synced ${_formatRelative(lastSynced)}.',
      actionLabel: 'Sync Now',
      isLoading: syncState.isLoading,
      onAction: () => ref.read(activitySyncControllerProvider.notifier).sync(),
      isSubtle: true,
    );
  }

  String _formatRelative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.isLoading = false,
    this.isSubtle = false,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isLoading;

  /// The "already working fine, just showing status" state glows quieter
  /// than the two states that need the user to actually do something.
  final bool isSubtle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: GlassCard(
        blurEnabled: false,
        glowColor: isSubtle ? null : accent,
        glowOpacity: 0.16,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: AppIcon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleSmall),
                  const SizedBox(height: 2),
                  Text(message, style: AppTextStyles.secondary(AppTextStyles.bodySmall)),
                  const SizedBox(height: AppSpacing.md),
                  isLoading
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                        )
                      : PremiumButton(
                          label: actionLabel,
                          variant: PremiumButtonVariant.glass,
                          size: PremiumButtonSize.small,
                          onPressed: onAction,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
