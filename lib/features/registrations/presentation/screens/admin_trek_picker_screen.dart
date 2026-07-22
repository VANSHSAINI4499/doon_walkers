import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/difficulty_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Trek picker for the Admin Dashboard's "Trek Registrations" card —
/// choose a trek to see only its registered members.
///
/// Reuses [adminAllTreksProvider] (no new query for this list, per the
/// brief) rather than the full Trek Library grid: this is a lightweight
/// picker, not a place to manage cover images or publish state, so a
/// plain list of title + difficulty + date is all it needs.
class AdminTrekPickerScreen extends ConsumerWidget {
  const AdminTrekPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final treksAsync = ref.watch(adminAllTreksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trek Registrations')),
      body: SafeArea(
        child: treksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('AdminTrekPickerScreen: failed to load treks: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load treks.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(adminAllTreksProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (treks) {
            if (treks.isEmpty) return const _EmptyTrekPicker();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: treks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final trek = treks[index];
                return _TrekPickerTile(
                  trek: trek,
                  onTap: () => context.push(
                    AppConstants.adminTrekRegistrationsLocation(trek.id),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyTrekPicker extends StatelessWidget {
  const _EmptyTrekPicker();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terrain_rounded, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No treks yet',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a trek from the Treks tab to see its registrations here.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrekPickerTile extends StatelessWidget {
  const _TrekPickerTile({required this.trek, required this.onTap});

  final Trek trek;
  final VoidCallback onTap;

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trekDate = trek.trekDate;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            trek.title,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DifficultyBadge(difficulty: trek.difficulty, dense: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      trekDate != null ? _formatDate(trekDate) : 'No date set',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: trekDate == null ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
