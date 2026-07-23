import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/profile/presentation/providers/leaderboard_visibility_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Show me on leaderboards" privacy toggle (Version 2, Phase C3).
/// Defaults on (matches the DB column's default) — this is a small
/// trusted community app, not a public one, so opt-OUT is the
/// friction-free path rather than requiring an explicit opt-in before
/// anyone appears ranked at all.
///
/// Reads its current value from [currentUserProvider] (which already
/// streams the caller's own row live) rather than tracking separate
/// local state — a successful write is picked up automatically the
/// same way any other profile field change would be, so this widget
/// never needs to reconcile "what I just set" against "what the server
/// says" itself.
class LeaderboardVisibilityToggle extends ConsumerWidget {
  const LeaderboardVisibilityToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);
    final isSaving = ref.watch(leaderboardVisibilityControllerProvider).isLoading;
    final showOnLeaderboard = userAsync.valueOrNull?.showOnLeaderboard ?? true;

    ref.listen<AsyncValue<void>>(leaderboardVisibilityControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          debugPrint('LeaderboardVisibilityToggle: update failed: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not update this setting. Please try again.'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        },
      );
    });

    return Card(
      elevation: 1,
      child: SwitchListTile(
        secondary: const Icon(Icons.leaderboard_outlined),
        title: const Text('Show me on leaderboards'),
        subtitle: const Text('Turn off to hide your name and rank from other members.'),
        value: showOnLeaderboard,
        onChanged: isSaving
            ? null
            : (value) => ref
                .read(leaderboardVisibilityControllerProvider.notifier)
                .setShowOnLeaderboard(value),
      ),
    );
  }
}
