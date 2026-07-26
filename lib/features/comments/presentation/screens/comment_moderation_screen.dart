import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/comments/presentation/providers/comment_providers.dart';
import 'package:doon_walkers/features/comments/presentation/widgets/comment_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Cross-trek comment moderation queue — every currently-hidden
/// comment, across every trek, in one place.
///
/// This is deliberately NOT the only way to moderate: inline hide/show
/// on [CommentTile] (rendered directly on Trek Detail) is the primary
/// surface, since that's where an admin naturally encounters a comment
/// in context. This screen answers a different question — "what have I
/// already hidden, anywhere" — the same relationship the flat
/// Registrations roster has to the per-trek one. Scoped to currently
/// hidden comments only (not a full "every comment everywhere" dump):
/// there's no "flagged/reported" concept in this phase, so hidden
/// comments — the ones actually needing a decision (leave hidden, or
/// restore) — are the only actionable state worth a dedicated queue.
///
/// Reachable only via `/admin/comments`, drawer/dashboard-only like
/// `/admin/registrations` — not a bottom-nav tab.
class CommentModerationScreen extends ConsumerWidget {
  const CommentModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final hiddenAsync = ref.watch(hiddenCommentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comment Moderation'),
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.block),
            tooltip: 'Manage blocklist',
            onPressed: () => context.push(AppConstants.routeCommentBlocklist),
          ),
        ],
      ),
      body: SafeArea(
        child: hiddenAsync.when(
          loading: () => const _ModerationQueueSkeleton(),
          error: (error, stack) {
            debugPrint('CommentModerationScreen: failed to load hidden comments: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(AppIcons.error, size: 40, color: palette.danger),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Could not load hidden comments.',
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumButton(
                      label: 'Retry',
                      icon: AppIcons.refresh,
                      variant: PremiumButtonVariant.glass,
                      size: PremiumButtonSize.small,
                      onPressed: () => ref.invalidate(hiddenCommentsProvider),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (comments) {
            Future<void> onRefresh() => ref.refresh(hiddenCommentsProvider.future);

            if (comments.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [_EmptyModerationQueue()],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
                itemCount: comments.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  return AppReveal(
                    index: index.clamp(0, 8),
                    child: CommentTile(comment: comments[index], showTrekTitle: true),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyModerationQueue extends StatelessWidget {
  const _EmptyModerationQueue();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: palette.primarySubtle,
              shape: BoxShape.circle,
              border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
            ),
            child: AppIcon(AppIcons.taskDone, size: 48, color: palette.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Nothing to review',
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Comments you hide from a trek page will show up here.',
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ModerationQueueSkeleton extends StatelessWidget {
  const _ModerationQueueSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: palette.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 180, height: 16),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 140, height: 12),
              SizedBox(height: AppSpacing.md),
              SkeletonBox(width: 240, height: 14),
            ],
          ),
        ),
      ),
    );
  }
}
