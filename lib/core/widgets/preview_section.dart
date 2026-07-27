import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/glass_states.dart';
import 'package:doon_walkers/core/widgets/section_title.dart';
import 'package:doon_walkers/core/widgets/view_all_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A Profile dashboard "preview" section — a [SectionTitle], up to 2
/// items, and a bottom-right [ViewAllButton] that only appears once
/// there's genuinely more than 2. Owns the loading/error/empty
/// rendering so [MyWishlistSection]/[MyInquiriesSection]/
/// [MyRegistrationsSection] don't each duplicate it.
///
/// [asyncItems] is expected to have been fetched with a limit of 3, not
/// 2 — that's what lets this decide whether to show "View All" without
/// a separate COUNT query per section on every Profile load: if a 3rd
/// item comes back, more exist (button shown); if fewer than 3 come
/// back, everything that exists is already on screen (no button). Only
/// the first 2 are ever displayed, regardless.
class PreviewSection<T> extends StatelessWidget {
  const PreviewSection({
    super.key,
    required this.title,
    required this.icon,
    this.accent = AppColors.primary,
    required this.asyncItems,
    required this.itemBuilder,
    required this.onViewAll,
    required this.onRetry,
    required this.errorMessage,
    required this.emptyIcon,
    required this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final String title;
  final IconData icon;
  final Color accent;

  /// Fetched with `limit: 3` — see this class's doc.
  final AsyncValue<List<T>> asyncItems;
  final Widget Function(T item) itemBuilder;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;
  final String errorMessage;

  final IconData emptyIcon;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  static const _previewCount = 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title: title, icon: icon, accent: accent),
        const SizedBox(height: AppSpacing.md),
        asyncItems.when(
          loading:
              () => const SkeletonList(
                count: 2,
                showImages: false,
                padding: EdgeInsets.zero,
              ),
          error:
              (error, stack) =>
                  GlassSectionError(message: errorMessage, onRetry: onRetry),
          data: (items) {
            if (items.isEmpty) {
              return GlassEmptyState(
                icon: emptyIcon,
                message: emptyMessage,
                actionLabel: emptyActionLabel,
                onAction: onEmptyAction,
              );
            }

            final visible = items.take(_previewCount).toList();
            final hasMore = items.length > _previewCount;

            return Column(
              children: [
                for (var i = 0; i < visible.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppReveal(index: i, child: itemBuilder(visible[i])),
                  ),
                if (hasMore) ViewAllButton(onTap: onViewAll),
              ],
            );
          },
        ),
      ],
    );
  }
}
