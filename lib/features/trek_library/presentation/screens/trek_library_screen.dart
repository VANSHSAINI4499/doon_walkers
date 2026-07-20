import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/trek_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Public Trek Library — published treks only, for every viewer
/// (guest, registered user, admin alike). Draft treks live only in the
/// admin trek list; see [publishedTreksProvider]'s doc for why.
class TrekLibraryScreen extends ConsumerWidget {
  const TrekLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final treksAsync = ref.watch(publishedTreksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trek Library')),
      body: SafeArea(
        child: treksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
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
                    onPressed: () => ref.invalidate(publishedTreksProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (treks) {
            if (treks.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => ref.refresh(publishedTreksProvider.future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [_EmptyTrekLibrary()],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(publishedTreksProvider.future),
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: treks.length,
                itemBuilder: (context, index) {
                  final trek = treks[index];
                  return TrekCard(
                    trek: trek,
                    onTap: () => context.push(AppConstants.trekDetailLocation(trek.id)),
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

class _EmptyTrekLibrary extends StatelessWidget {
  const _EmptyTrekLibrary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hiking_rounded, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No treks published yet',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back soon — new treks are on the way.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
