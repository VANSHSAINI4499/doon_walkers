import 'dart:typed_data';

import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';

/// Abstract interface for reading and managing merchandise products.
///
/// The read methods are safe to call regardless of caller role — RLS
/// (0016_merchandise_catalog.sql) already restricts what rows come
/// back. The write methods are only ever exposed through admin-gated
/// UI, but RLS enforces the same admin-only rule server-side either
/// way, backed by matching storage.objects policies on the
/// `merch-images` bucket (0017_merch_images_storage.sql).
abstract class ProductRepository {
  /// Active products only — used by the public catalog screen for
  /// every viewer, admin included, so an admin browsing the shared
  /// screen sees the same list a guest would; drafts only show up in
  /// the admin catalog view.
  ///
  /// One-shot fetch, not a live stream — same reasoning as
  /// [fetchAllProducts] and every other catalog-shaped list in this
  /// project (treks, gallery): a small admin-managed list, not worth an
  /// open channel per session.
  Future<List<Product>> fetchActiveProducts();

  /// All products, active and draft. RLS only actually returns drafts
  /// to an admin caller — for anyone else this behaves the same as
  /// [fetchActiveProducts].
  Future<List<Product>> fetchAllProducts();

  /// A single product by id, or `null` if it doesn't exist *or* the
  /// caller isn't allowed to see it (e.g. a guest requesting an
  /// inactive product's id) — RLS makes those two cases
  /// indistinguishable, which is the point.
  Future<Product?> fetchProductById(String id);

  /// Creates a product (starts inactive/draft — see the migration's
  /// `is_active` default) with no size variants and no images yet.
  /// Sizes are added via [addVariant]/[updateVariantStock]/
  /// [deleteVariant] and photos via [uploadImage], both after creation
  /// — mirrors how a trek's gallery is managed on its detail page
  /// rather than in the create form.
  Future<Product> createProduct({
    required String name,
    required String description,
    required double price,
    required ProductCategory category,
    required int stockQuantity,
  });

  Future<void> updateProduct({
    required String id,
    required String name,
    required String description,
    required double price,
    required ProductCategory category,
    required int stockQuantity,
  });

  /// Deletes the product row. `product_variants`/`product_images` rows
  /// cascade automatically (FK ON DELETE CASCADE); their Storage
  /// objects don't (no DB foreign key reaches into Storage), so this
  /// best-effort removes every image file first — see impl.
  Future<void> deleteProduct(String id);

  Future<void> setActive(String id, bool isActive);

  /// Inserts a new size row. Fails with a Postgres unique-violation if
  /// [size] already exists for this product — same guarantee the
  /// `UNIQUE (product_id, size)` constraint gives at the DB level.
  Future<ProductVariant> addVariant({
    required String productId,
    required String size,
    required int stockQuantity,
  });

  Future<void> updateVariantStock({
    required String variantId,
    required int stockQuantity,
  });

  Future<void> deleteVariant(String variantId);

  /// Uploads [bytes] to the `merch-images` bucket under [productId] and
  /// inserts the corresponding `public.product_images` row. Always
  /// uploads to a fresh, timestamped path — same reasoning as trek
  /// cover/gallery uploads (avoids a stale cached file at a reused
  /// path).
  Future<ProductImage> uploadImage({
    required String productId,
    required Uint8List bytes,
    required String fileExtension,
  });

  /// Deletes the image row. Best-effort deletes the underlying Storage
  /// object first (see impl) — Storage objects aren't tied to the row
  /// by a DB foreign key, so nothing does this automatically.
  Future<void> deleteImage(String id);
}
