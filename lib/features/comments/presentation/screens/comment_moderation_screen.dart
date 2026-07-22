import 'package:doon_walkers/core/constants/app_constants.dart';
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
    final theme = Theme.of(context);
    final hiddenAsync = ref.watch(hiddenCommentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comment Moderation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.block_rounded),
            tooltip: 'Manage blocklist',
            onPressed: () => context.push(AppConstants.routeCommentBlocklist),
          ),
        ],
      ),
      body: SafeArea(
        child: hiddenAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('CommentModerationScreen: failed to load hidden comments: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load hidden comments.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(hiddenCommentsProvider),
                      child: const Text('Retry'),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: comments.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  // No navigate-to-trek tap here — CommentTile already
                  // has its own interactive Hide/Delete buttons, and
                  // review + unhide (this queue's actual job) doesn't
                  // need a trip to the trek page. showTrekTitle gives
                  // enough context without it.
                  return CommentTile(comment: comments[index], showTrekTitle: true);
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt_rounded, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Nothing to review',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Comments you hide from a trek page will show up here.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
