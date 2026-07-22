/// Maps 1-to-1 with the `product_category` enum in Postgres (`apparel`,
/// `headwear`, `drinkware`, `accessories`, `stickers`, `other`) — see
/// 0016_merchandise_catalog.sql.
enum ProductCategory {
  apparel,
  headwear,
  drinkware,
  accessories,
  stickers,
  other;

  /// Matches the Dart enum's identifier name exactly to the Postgres
  /// enum value — deliberately kept 1:1 so `.name` round-trips safely.
  static ProductCategory fromString(String? value) {
    return ProductCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => ProductCategory.other, // matches the DB column default
    );
  }

  String toDbString() => name;

  String get label => switch (this) {
    ProductCategory.apparel => 'Apparel',
    ProductCategory.headwear => 'Headwear',
    ProductCategory.drinkware => 'Drinkware',
    ProductCategory.accessories => 'Accessories',
    ProductCategory.stickers => 'Stickers',
    ProductCategory.other => 'Other',
  };
}

/// A single size's stock — a row in `public.product_variants`. Only
/// exists for a product that actually has sizes; see [Product]'s doc
/// for the no-variants case.
class ProductVariant {
  final String id;
  final String productId;
  final String size;
  final int stockQuantity;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.size,
    required this.stockQuantity,
  });

  bool get isInStock => stockQuantity > 0;
}

/// A single product photo — a row in `public.product_images`. No
/// separate "cover image" concept: the app treats the oldest-uploaded
/// row (see [Product.coverImageUrl]) as the catalog thumbnail.
class ProductImage {
  final String id;
  final String productId;
  final String imageUrl;
  final DateTime uploadedAt;

  const ProductImage({
    required this.id,
    required this.productId,
    required this.imageUrl,
    required this.uploadedAt,
  });
}

/// Core domain representation of a row in `public.products`, with its
/// nested [variants] and [images] (both one-to-many, fetched via a
/// single joined query — see ProductRepository).
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final ProductCategory category;

  /// Meaningful ONLY when [variants] is empty — see [isInStock]. Once a
  /// product has any variant rows, stock is tracked per-size instead
  /// and this field is ignored.
  final int stockQuantity;

  final bool isActive;
  final DateTime createdAt;

  /// Empty for a "one-size" product — see this class's top doc and
  /// 0016_merchandise_catalog.sql's reasoning for why this is a
  /// separate table rather than a flag + size list on the product row.
  final List<ProductVariant> variants;

  /// Ordered oldest-first (see repository) so [coverImageUrl] is stable
  /// — the first photo an admin ever uploaded stays the catalog
  /// thumbnail even after more are added later.
  final List<ProductImage> images;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.stockQuantity,
    required this.isActive,
    required this.createdAt,
    this.variants = const [],
    this.images = const [],
  });

  bool get hasVariants => variants.isNotEmpty;

  /// True when this product can currently be bought — never surfaced
  /// to non-admin UI as an exact number (see the product card/detail
  /// screens), only this yes/no, to avoid handing out inventory counts
  /// to anyone browsing the catalog.
  bool get isInStock => hasVariants ? variants.any((v) => v.isInStock) : stockQuantity > 0;

  /// The catalog-card/detail-hero thumbnail — the oldest uploaded photo,
  /// or `null` if none have been added yet (shows a placeholder icon).
  String? get coverImageUrl => images.isEmpty ? null : images.first.imageUrl;
}
