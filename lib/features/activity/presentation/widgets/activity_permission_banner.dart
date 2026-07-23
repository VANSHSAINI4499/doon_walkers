import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/domain/repositories/activity_provider.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fitness-sync status banner shown at the top of the Challenges tab —
/// the graceful-degradation surface the Challenges Module pivot brief
/// explicitly asked for: a device without Health Connect should see a
/// clear explanation and a path forward, never a broken feature or a
/// crash.
///
/// Hidden entirely for guests (nothing to sync to) — [AuthGuard]-style
/// sign-in prompts already cover that elsewhere on this screen
/// (ChallengeCard's own per-card sign-in prompt); this banner is about
/// the DEVICE's fitness-data source, a separate concern from being
/// signed in at all.
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

    // Still resolving either check — render nothing rather than a
    // flash of "unavailable" that immediately flips to something else.
    if (availabilityAsync.isLoading || permissionAsync.isLoading) {
      return const SizedBox.shrink();
    }

    final availability = availabilityAsync.valueOrNull;
    final hasPermission = permissionAsync.valueOrNull ?? false;

    if (availability == ActivityAvailability.unavailable) {
      return _Banner(
        icon: Icons.download_outlined,
        title: 'Health Connect required',
        message: 'Install or update Health Connect to track fitness challenges '
            '(steps, distance, calories).',
        actionLabel: 'Install',
        onAction: () => ref.read(activityProviderProvider).openProviderSettings(),
      );
    }

    if (!hasPermission) {
      return _Banner(
        icon: Icons.health_and_safety_outlined,
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
      icon: Icons.sync_rounded,
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
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.isLoading = false,
    this.isSubtle = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isLoading;

  /// The "already working fine, just showing status" state uses a
  /// quieter container than the two states that need the user to
  /// actually do something.
  final bool isSubtle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        isSubtle ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primaryContainer;
    final foreground =
        isSubtle ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                ),
                const SizedBox(height: 8),
                isLoading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                      )
                    : TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: foreground,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onAction,
                        child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
