import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/comments/domain/entities/comment.dart';
import 'package:doon_walkers/features/comments/presentation/providers/comment_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One comment — shared by the trek-scoped thread (Trek Detail) and the
/// cross-trek moderation queue, rather than each keeping its own copy.
///
/// A hidden comment only ever reaches this widget for an admin viewer —
/// `comments_select`'s RLS bypass for admin is what makes that true,
/// not any filtering here (see [CommentRepository]'s doc) — so
/// [comment.isVisible] being false is trusted as "the viewer is
/// admin," and rendered with a visible "Hidden" marker rather than
/// silently looking identical to a normal comment.
///
/// [showTrekTitle] is for the moderation queue, which spans every
/// trek — same optional-parameter reuse pattern as
/// `RegistrationTile.showTrekTitle`.
class CommentTile extends ConsumerStatefulWidget {
  const CommentTile({
    super.key,
    required this.comment,
    this.showTrekTitle = false,
  });

  final Comment comment;
  final bool showTrekTitle;

  @override
  ConsumerState<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<CommentTile> {
  bool _isPending = false;

  Future<void> _toggleVisibility() async {
    final c = widget.comment;
    setState(() => _isPending = true);
    final success = await ref.read(commentControllerProvider.notifier).setVisibility(
          id: c.id,
          trekId: c.trekId,
          isVisible: !c.isVisible,
        );
    if (!mounted) return;
    setState(() => _isPending = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not update this comment. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This removes the comment permanently. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final c = widget.comment;
    setState(() => _isPending = true);
    final success = await ref
        .read(commentControllerProvider.notifier)
        .deleteComment(id: c.id, trekId: c.trekId);
    if (!mounted) return;
    setState(() => _isPending = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not delete this comment. Please try again.'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.comment;
    final currentUserId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final isAdmin = ref.watch(isAdminProvider);
    final isOwnComment = currentUserId != null && currentUserId == c.userId;
    final avatar = c.userAvatar;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.isVisible
            ? theme.colorScheme.surfaceContainerHighest.withAlpha(90)
            : theme.colorScheme.errorContainer.withAlpha(60),
        borderRadius: BorderRadius.circular(12),
        border: c.isVisible
            ? null
            : Border.all(color: theme.colorScheme.error.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: (avatar != null && avatar.isNotEmpty)
                    ? NetworkImage(avatar)
                    : null,
                child: (avatar == null || avatar.isEmpty)
                    ? Text(
                        c.userName.isNotEmpty ? c.userName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.userName,
                            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!c.isVisible) ...[
                          const SizedBox(width: 6),
                          _HiddenBadge(theme: theme),
                        ],
                      ],
                    ),
                    if (widget.showTrekTitle && (c.trekTitle ?? '').isNotEmpty)
                      Text(
                        'on ${c.trekTitle}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      _formatCommentDate(c.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.commentText, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          if (isOwnComment || isAdmin) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isPending)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  if (isAdmin)
                    TextButton.icon(
                      onPressed: _toggleVisibility,
                      icon: Icon(
                        c.isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 16,
                      ),
                      label: Text(c.isVisible ? 'Hide' : 'Unhide'),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  if (isOwnComment || isAdmin)
                    TextButton.icon(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HiddenBadge extends StatelessWidget {
  const _HiddenBadge({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Hidden',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onError,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

String _formatCommentDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = dt.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
