import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/difficulty_badge.dart';
import 'package:flutter/material.dart';

/// Card summary for a trek in the public library grid/list — cover
/// image, title, difficulty badge, distance/duration at a glance.
class TrekCard extends StatelessWidget {
  const TrekCard({super.key, required this.trek, required this.onTap});

  final Trek trek;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverImage = trek.coverImage;

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
              child: (coverImage == null || coverImage.isEmpty)
                  ? const _CoverPlaceholder()
                  : Image.network(
                      coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const _CoverPlaceholder(),
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
