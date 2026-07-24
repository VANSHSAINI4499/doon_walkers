import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/profile/presentation/providers/leaderboard_visibility_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Show me on leaderboards" privacy toggle. Reads its current value from
/// [currentUserProvider] (which streams the caller's own row live) and
/// writes through [leaderboardVisibilityControllerProvider], which updates
/// the real `show_on_leaderboard` column the leaderboard RPC reads — it is
/// **not** local-only state.
///
/// Redesign Phase 5 restyles it as a glass settings row. The read source,
/// the write path, the saving/disabled handling, and the error snackbar
/// are all unchanged.
class LeaderboardVisibilityToggle extends ConsumerWidget {
  const LeaderboardVisibilityToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final isSaving = ref.watch(leaderboardVisibilityControllerProvider).isLoading;
    final showOnLeaderboard = userAsync.valueOrNull?.showOnLeaderboard ?? true;

    ref.listen<AsyncValue<void>>(leaderboardVisibilityControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          debugPrint('LeaderboardVisibilityToggle: update failed: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not update this setting. Please try again.'),
              backgroundColor: AppColors.danger,
            ),
          );
        },
      );
    });

    return GlassCard(
      blurEnabled: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const AppIcon(AppIcons.leaderboard, size: 20, color: AppColors.secondary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Show me on leaderboards', style: AppTextStyles.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Turn off to hide your name and rank from other members.',
                  style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch(
            value: showOnLeaderboard,
            onChanged: isSaving
                ? null
                : (value) => ref
                    .read(leaderboardVisibilityControllerProvider.notifier)
                    .setShowOnLeaderboard(value),
          ),
        ],
      ),
    );
  }
}
