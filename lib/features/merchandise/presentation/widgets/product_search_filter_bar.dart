import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:flutter/material.dart';

/// Search field + category filter chips for the catalog screen.
///
/// [searchController] is owned by the parent's State (not created here)
/// — a TextField's controller must survive rebuilds, so a fresh one
/// created inline on every build would fight the IME and reset the
/// cursor/selection on every keystroke. Filtering itself happens in the
/// parent from the controller's text; catalog sizes here (tens of
/// products, same order of magnitude as the trek library) are small
/// enough that client-side filtering over an already-fetched list is
/// simpler than a server-side search endpoint, matching how
/// [sortTreksForLibrary] already sorts client-side at this project's
/// scale.
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
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      tooltip: 'Clear search',
                      onPressed: onClearSearch,
                    ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
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
                const SizedBox(width: 8),
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
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
