import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/difficulty_badge.dart';
import 'package:flutter/material.dart';

/// Card summary for a trek in the public library grid/list — cover
/// image, title, difficulty badge, distance/duration at a glance.
///
/// The same card serves every role. [adminActions] is the only
/// role-dependent part: the Trek Library screen passes a
/// [TrekAdminActions] menu when the viewer is an admin and `null`
/// otherwise, so guests and members see an identical card with no
/// admin affordances rather than a separate screen.
class TrekCard extends StatelessWidget {
  const TrekCard({
    super.key,
    required this.trek,
    required this.onTap,
    this.adminActions,
  });

  final Trek trek;
  final VoidCallback onTap;

  /// Admin-only overlay menu; `null` for non-admin viewers.
  final Widget? adminActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverImage = trek.coverImage;
    final isAdminView = adminActions != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (coverImage == null || coverImage.isEmpty)
                      ? const _CoverPlaceholder()
                      : Image.network(
                          coverImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => const _CoverPlaceholder(),
                        ),
                  // Draft marker — only meaningful to an admin, since RLS
                  // never returns unpublished treks to anyone else.
                  if (isAdminView && !trek.isPublished)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Draft',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isAdminView)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(90),
                          shape: BoxShape.circle,
                        ),
                        child: adminActions!,
                      ),
                    ),
                  // Bottom-left so it never collides with the draft
                  // marker (top-left) or the admin actions menu
                  // (top-right). Automatic from trek_date — see
                  // Trek.isUpcoming — never a manually-set flag.
                  if (trek.isUpcoming)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              size: 12,
                              color: theme.colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Upcoming',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          trek.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DifficultyBadge(difficulty: trek.difficulty, dense: true),
                    ],
                  ),
                  if (trek.distanceKm != null || trek.durationDays != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (trek.distanceKm != null)
                          _FactChip(
                            icon: Icons.straighten_rounded,
                            label: '${_formatDistance(trek.distanceKm!)} km',
                          ),
                        if (trek.distanceKm != null && trek.durationDays != null)
                          const SizedBox(width: 10),
                        if (trek.durationDays != null)
                          _FactChip(
                            icon: Icons.calendar_today_outlined,
                            label: '${trek.durationDays} ${trek.durationDays == 1 ? 'day' : 'days'}',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double km) => km % 1 == 0 ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.landscape_rounded,
        size: 40,
        color: theme.colorScheme.outline,
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
