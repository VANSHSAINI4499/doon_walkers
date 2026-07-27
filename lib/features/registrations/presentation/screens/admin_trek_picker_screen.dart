import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
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
    final palette = AppPalette.of(context);
    final treksAsync = ref.watch(adminAllTreksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trek Registrations')),
      body: SafeArea(
        child: treksAsync.when(
          loading: () => const _TrekPickerSkeleton(),
          error: (error, stack) {
            debugPrint('AdminTrekPickerScreen: failed to load treks: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(AppIcons.error, size: 40, color: palette.danger),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Could not load treks.',
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumButton(
                      label: 'Retry',
                      icon: AppIcons.refresh,
                      variant: PremiumButtonVariant.glass,
                      size: PremiumButtonSize.small,
                      onPressed: () => ref.invalidate(adminAllTreksProvider),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (treks) {
            if (treks.isEmpty) return const _EmptyTrekPicker();

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              itemCount: treks.length,
              separatorBuilder:
                  (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final trek = treks[index];
                return AppReveal(
                  index: index.clamp(0, 8),
                  child: _TrekPickerTile(
                    trek: trek,
                    onTap:
                        () => context.push(
                          AppConstants.adminTrekRegistrationsLocation(trek.id),
                        ),
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
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: palette.primarySubtle,
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.3),
                ),
              ),
              child: AppIcon(AppIcons.treks, size: 48, color: palette.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No treks yet',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add a trek from the Treks tab to see its registrations here.',
              style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final trekDate = trek.trekDate;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                        style: AppTextStyles.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    DifficultyBadge(difficulty: trek.difficulty, dense: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  trekDate != null ? _formatDate(trekDate) : 'No date set',
                  style: AppTextStyles.secondary(
                    AppTextStyles.bodySmall,
                  ).copyWith(
                    fontStyle:
                        trekDate == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppIcon(AppIcons.chevronRight, color: palette.textSecondary),
        ],
      ),
    );
  }
}

class _TrekPickerSkeleton extends StatelessWidget {
  const _TrekPickerSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 4,
        separatorBuilder:
            (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder:
            (context, index) => Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: palette.border),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 180, height: 16),
                        SizedBox(height: AppSpacing.sm),
                        SkeletonBox(width: 100, height: 12),
                      ],
                    ),
                  ),
                  SkeletonBox(
                    width: 24,
                    height: 24,
                    borderRadius: AppRadius.xs,
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
