import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/comments/domain/entities/comment.dart';
import 'package:doon_walkers/features/comments/presentation/providers/comment_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One comment — shared by the trek-scoped thread (Trek Detail) and the
/// cross-trek moderation queue, rather than each keeping its own copy.
///
/// A hidden comment only ever reaches this widget for an admin viewer —
/// `comments_select`'s RLS bypass for admin is what makes that true, not
/// any filtering here — so [comment.isVisible] being false is trusted as
/// "the viewer is admin," and rendered with a visible "Hidden" marker
/// rather than silently looking identical to a normal comment.
///
/// [showTrekTitle] is for the moderation queue, which spans every trek.
///
/// Redesign Phase 3 restyles this onto the design system. Every rule is
/// unchanged: who sees the Hide/Unhide and Delete controls (admin, and the
/// author for delete), the hidden-comment styling, and the mutations.
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
        const SnackBar(
          content: Text('Could not update this comment. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This removes the comment permanently. This cannot be undone.'),
        actions: [
          PremiumButton(
            label: 'Keep it',
            variant: PremiumButtonVariant.glass,
            size: PremiumButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PremiumButton(
            label: 'Delete',
            icon: AppIcons.delete,
            variant: PremiumButtonVariant.danger,
            size: PremiumButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
        const SnackBar(
          content: Text('Could not delete this comment. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final currentUserId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final isAdmin = ref.watch(isAdminProvider);
    final isOwnComment = currentUserId != null && currentUserId == c.userId;
    final avatar = c.userAvatar;

    return GlassCard(
      blurEnabled: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderRadius: AppRadius.card,
      // Hidden comments (admin-only, per the class doc) get a danger-tinted
      // treatment so they never look like a normal comment.
      glowColor: c.isVisible ? null : AppColors.danger,
      glowOpacity: 0.12,
      borderColor: c.isVisible ? null : AppColors.danger.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryContainer,
                backgroundImage: (avatar != null && avatar.isNotEmpty)
                    ? NetworkImage(avatar)
                    : null,
                child: (avatar == null || avatar.isEmpty)
                    ? Text(
                        c.userName.isNotEmpty ? c.userName[0].toUpperCase() : '?',
                        style: AppTextStyles.tinted(AppTextStyles.labelLarge, AppColors.primaryLight),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.userName,
                            style: AppTextStyles.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!c.isVisible) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const _HiddenBadge(),
                        ],
                      ],
                    ),
                    if (widget.showTrekTitle && (c.trekTitle ?? '').isNotEmpty)
                      Text(
                        'on ${c.trekTitle}',
                        style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      _formatCommentDate(c.createdAt),
                      style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(c.commentText, style: AppTextStyles.bodyMedium),
          if (isOwnComment || isAdmin) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isPending)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                else ...[
                  if (isAdmin)
                    TextButton.icon(
                      onPressed: _toggleVisibility,
                      icon: AppIcon(
                        c.isVisible ? AppIcons.hidden : AppIcons.visible,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      label: Text(
                        c.isVisible ? 'Hide' : 'Unhide',
                        style: AppTextStyles.secondary(AppTextStyles.labelMedium),
                      ),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  if (isOwnComment || isAdmin)
                    TextButton.icon(
                      onPressed: _confirmDelete,
                      icon: const AppIcon(AppIcons.delete, size: 16, color: AppColors.danger),
                      label: Text(
                        'Delete',
                        style: AppTextStyles.tinted(AppTextStyles.labelMedium, AppColors.danger),
                      ),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
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
  const _HiddenBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Hidden',
        style: AppTextStyles.tinted(AppTextStyles.labelSmall, AppColors.onDanger),
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
