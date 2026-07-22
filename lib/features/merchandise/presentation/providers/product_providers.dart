import 'dart:async';
import 'dart:typed_data';

import 'package:doon_walkers/features/merchandise/data/repositories/product_repository_impl.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active products only — the public Merchandise Catalog screen, for
/// every viewer, admin included. See
/// [ProductRepository.fetchActiveProducts].
///
/// One-shot fetch, not a live stream — same reasoning as
/// `publishedTreksProvider`: a small admin-managed catalog, not worth
/// an open channel per session. Refetches via pull-to-refresh or the
/// error state's Retry button.
final activeProductsProvider = FutureProvider<List<Product>>(
  (ref) => ref.watch(productRepositoryProvider).fetchActiveProducts(),
  name: 'activeProductsProvider',
);

/// All products (active + draft) — admin catalog view. RLS returns
/// draft rows only when the caller is actually an admin; anyone else
/// gets the same result as [activeProductsProvider].
final adminAllProductsProvider = FutureProvider<List<Product>>(
  (ref) => ref.watch(productRepositoryProvider).fetchAllProducts(),
  name: 'adminAllProductsProvider',
);

/// A single product by id, for the Product Detail screen. `autoDispose`
/// since detail pages are visited transiently — no reason to keep
/// every product a user has ever opened cached for the whole app
/// session.
final productByIdProvider = FutureProvider.autoDispose.family<Product?, String>(
  (ref, id) => ref.watch(productRepositoryProvider).fetchProductById(id),
  name: 'productByIdProvider',
);

/// Riverpod AsyncNotifier managing admin product mutations (create,
/// update, delete, active toggle, size/variant CRUD). Mirrors
/// TrekAdminController's shape: [state] is shared loading/error status
/// across all actions; each method also returns its own result so
/// callers don't have to read state.value.
final productAdminControllerProvider = AsyncNotifierProvider<ProductAdminController, void>(
  ProductAdminController.new,
  name: 'productAdminControllerProvider',
);

class ProductAdminController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Creates a product (starts inactive — see repository) with the
  /// given sizes, if any. Sizes are added right after the product row
  /// exists (mirrors uploading a trek's cover image after creation),
  /// so a partial failure here still leaves the product itself saved.
  Future<Product?> createProduct({
    required String name,
    required String description,
    required double price,
    required ProductCategory category,
    required int stockQuantity,
    List<(String size, int stock)> variants = const [],
  }) async {
    state = const AsyncLoading();
    Product? created;
    state = await AsyncValue.guard(() async {
      final repo = ref.read(productRepositoryProvider);
      final product = await repo.createProduct(
        name: name,
        description: description,
        price: price,
        category: category,
        stockQuantity: stockQuantity,
      );
      created = product;

      for (final (size, stock) in variants) {
        await repo.addVariant(productId: product.id, size: size, stockQuantity: stock);
      }
    });
    return created;
  }

  /// Updates a product's core fields, then reconciles its size list
  /// against [variants]: removes rows no longer present, updates stock
  /// for existing sizes, and adds newly introduced ones. [existing] is
  /// the product's variant list as loaded before editing — the form
  /// diffs against this rather than blindly delete-then-recreate-all,
  /// so an existing variant's id (and therefore any future FK reference
  /// to it) survives a plain stock edit.
  Future<bool> updateProduct({
    required String id,
    required String name,
    required String description,
    required double price,
    required ProductCategory category,
    required int stockQuantity,
    required List<ProductVariant> existing,
    List<(String size, int stock)> variants = const [],
  }) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      final repo = ref.read(productRepositoryProvider);
      await repo.updateProduct(
        id: id,
        name: name,
        description: description,
        price: price,
        category: category,
        stockQuantity: stockQuantity,
      );
      success = true;

      final existingBySize = {for (final v in existing) v.size: v};
      final newSizes = variants.map((v) => v.$1).toSet();

      for (final old in existing) {
        if (!newSizes.contains(old.size)) {
          await repo.deleteVariant(old.id);
        }
      }
      for (final (size, stock) in variants) {
        final match = existingBySize[size];
        if (match == null) {
          await repo.addVariant(productId: id, size: size, stockQuantity: stock);
        } else if (match.stockQuantity != stock) {
          await repo.updateVariantStock(variantId: match.id, stockQuantity: stock);
        }
      }
    });
    return success;
  }

  Future<bool> deleteProduct(String id) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(productRepositoryProvider).deleteProduct(id);
      success = true;
    });
    return success;
  }

  Future<bool> setActive(String id, bool isActive) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(productRepositoryProvider).setActive(id, isActive);
      success = true;
    });
    return success;
  }
}

/// Riverpod AsyncNotifier managing admin product-photo mutations
/// (upload, delete). Mirrors GalleryAdminController's shape exactly —
/// same one-to-many-media-on-a-detail-page pattern, different table.
final productImageAdminControllerProvider =
    AsyncNotifierProvider<ProductImageAdminController, void>(
  ProductImageAdminController.new,
  name: 'productImageAdminControllerProvider',
);

class ProductImageAdminController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<ProductImage?> uploadImage({
    required String productId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    state = const AsyncLoading();
    ProductImage? uploaded;
    state = await AsyncValue.guard(() async {
      uploaded = await ref.read(productRepositoryProvider).uploadImage(
            productId: productId,
            bytes: bytes,
            fileExtension: fileExtension,
          );
    });
    return uploaded;
  }

  Future<bool> deleteImage(String id) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(productRepositoryProvider).deleteImage(id);
      success = true;
    });
    return success;
  }
}
