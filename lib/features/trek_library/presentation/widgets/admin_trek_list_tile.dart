import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/difficulty_badge.dart';
import 'package:flutter/material.dart';

/// One row in the admin trek list — thumbnail, title, published/draft
/// status, difficulty, and an actions menu (edit / publish-toggle /
/// delete). [isPending] disables just this row's actions and shows a
/// small spinner in place of the menu, while other rows stay usable.
class AdminTrekListTile extends StatelessWidget {
  const AdminTrekListTile({
    super.key,
    required this.trek,
    required this.isPending,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublished,
  });

  final Trek trek;
  final bool isPending;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePublished;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverImage = trek.coverImage;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: (coverImage == null || coverImage.isEmpty)
                    ? Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.landscape_rounded, color: theme.colorScheme.outline),
                      )
                    : Image.network(
                        coverImage,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.outline),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trek.title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatusChip(isPublished: trek.isPublished),
                      DifficultyBadge(difficulty: trek.difficulty, dense: true),
                    ],
                  ),
                ],
              ),
            ),
            if (isPending)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'toggle':
                      onTogglePublished();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      leading: Icon(trek.isPublished ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      title: Text(trek.isPublished ? 'Unpublish' : 'Publish'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                      title: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isPublished});

  final bool isPublished;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isPublished ? AppColors.difficultyEasy : theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPublished ? Icons.public_rounded : Icons.edit_note_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            isPublished ? 'Published' : 'Draft',
            style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
