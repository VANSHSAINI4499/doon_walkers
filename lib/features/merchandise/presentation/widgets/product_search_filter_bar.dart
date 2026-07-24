import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:flutter/material.dart';

/// Search field + category filter chips for the catalog screen.
///
/// [searchController] is owned by the parent's State (not created here) —
/// a TextField's controller must survive rebuilds. Filtering itself
/// happens in the parent from the controller's text (client-side, at this
/// project's catalog scale). Redesign Phase 6 restyles the field and chips
/// onto the design system; the filtering behaviour is unchanged.
class ProductSearchFilterBar extends StatelessWidget {
  const ProductSearchFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  /// `null` means "All categories".
  final ProductCategory? selectedCategory;
  final ValueChanged<ProductCategory?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: searchController,
          builder: (context, _) => TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search merchandise…',
              prefixIcon: const AppIcon(AppIcons.search, size: 20, color: AppColors.textSecondary),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const AppIcon(AppIcons.close, size: 18, color: AppColors.textSecondary),
                      tooltip: 'Clear search',
                      onPressed: onClearSearch,
                    ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CategoryChip(
                label: 'All',
                selected: selectedCategory == null,
                onSelected: () => onCategoryChanged(null),
              ),
              for (final category in ProductCategory.values) ...[
                const SizedBox(width: AppSpacing.sm),
                _CategoryChip(
                  label: category.label,
                  selected: selectedCategory == category,
                  onSelected: () => onCategoryChanged(category),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.primary : null,
          color: selected ? null : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.glassBorder,
          ),
          boxShadow: selected ? AppShadows.glow(AppColors.primary, opacity: 0.3, radius: 10) : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.tinted(
            AppTextStyles.labelMedium,
            selected ? AppColors.onPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
