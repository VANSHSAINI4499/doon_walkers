import 'package:flutter/material.dart';

/// Shared empty-state card for Home's Upcoming Trek / Featured Trek /
/// Recent Memories sections.
///
/// Phase 3 does not query `treks` or `gallery` at all (that's Phase
/// 4/5) — this always renders; it isn't a "no rows found" branch of a
/// real query. That keeps Home honest about what exists today instead
/// of showing fabricated trek data.
class TrekSectionPlaceholder extends StatelessWidget {
  const TrekSectionPlaceholder({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
