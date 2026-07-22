import 'dart:typed_data';

import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/merchandise/data/models/product_model.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/domain/repositories/product_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod provider exposing the implementation of [ProductRepository].
final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepositoryImpl(ref.watch(supabaseClientProvider)),
  name: 'productRepositoryProvider',
);

/// Nested-join shape shared by every full-product read — pulls a
/// product's variants and images in the same round trip rather than
/// N+1 queries per card.
const _fullProductSelect = '*, product_variants(*), product_images(*)';

/// Supabase implementation of [ProductRepository].
class ProductRepositoryImpl implements ProductRepository {
  final SupabaseClient _supabase;

  const ProductRepositoryImpl(this._supabase);

  @override
  Future<List<Product>> fetchActiveProducts() async {
    final rows = await _supabase
        .from(AppConstants.tableProducts)
        .select(_fullProductSelect)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return rows.map(ProductModel.fromJson).toList();
  }

  @override
  Future<List<Product>> fetchAllProducts() async {
    final rows = await _supabase
        .from(AppConstants.tableProducts)
        .select(_fullProductSelect)
        .order('created_at', ascending: false);
    return rows.map(ProductModel.fromJson).toList();
  }

  @override
  Future<Product?> fetchProductById(String id) async {
    final row = await _supabase
        .from(AppConstants.tableProducts)
        .select(_fullProductSelect)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ProductModel.fromJson(row);
  }

  @override
  Future<Product> createProduct({
    required String name,
    required String description,
    required double price,
    required ProductCategory category,
    required int stockQuantity,
  }) async {
    final row = await _supabase
        .from(AppConstants.tableProducts)
        .insert(_writablePayload(
          name: name,
          description: description,
          price: price,
          category: category,
          stockQuantity: stockQuantity,
        ))
        .select()
        .single();
    // is_active isn't in the insert payload — it defaults to FALSE at
    // the DB level, so every new product starts as a draft. No
    // variants/images yet either — a fresh row parses to empty lists.
    return ProductModel.fromJson(row);
  }

  @override
  Future<void> updateProduct({
    required String id,
    required String name,
    required String description,
    required double price,
    required ProductCategory category,
    required int stockQuantity,
  }) async {
    await _supabase
        .from(AppConstants.tableProducts)
        .update(_writablePayload(
          name: name,
          description: description,
          price: price,
          category: category,
          stockQuantity: stockQuantity,
        ))
        .eq('id', id);
  }

  @override
  Future<void> deleteProduct(String id) async {
    // Storage objects aren't tied to rows by a DB foreign key — nothing
    // cascades this automatically, so clean them all up first.
    // Best-effort: a failed cleanup shouldn't block deleting the
    // product itself, it just leaves orphaned files at worst.
    try {
      final imageRows = await _supabase
          .from(AppConstants.tableProductImages)
          .select('image_url')
          .eq('product_id', id);
      final paths = imageRows
          .map((row) => _extractObjectPath(row['image_url'] as String))
          .whereType<String>()
          .toList();
      if (paths.isNotEmpty) {
        await _supabase.storage.from(AppConstants.bucketMerchImages).remove(paths);
      }
    } catch (_) {
      // Orphaned files at worst — not worth failing the delete over.
    }

    // product_variants and product_images rows cascade automatically
    // (ON DELETE CASCADE) — only the product row itself needs deleting.
    await _supabase.from(AppConstants.tableProducts).delete().eq('id', id);
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    await _supabase
        .from(AppConstants.tableProducts)
        .update({'is_active': isActive}).eq('id', id);
  }

  @override
  Future<ProductVariant> addVariant({
    required String productId,
    required String size,
    required int stockQuantity,
  }) async {
    final row = await _supabase
        .from(AppConstants.tableProductVariants)
        .insert({
          'product_id': productId,
          'size': size,
          'stock_quantity': stockQuantity,
        })
        .select()
        .single();
    return ProductVariantModel.fromJson(row);
  }

  @override
  Future<void> updateVariantStock({
    required String variantId,
    required int stockQuantity,
  }) async {
    await _supabase
        .from(AppConstants.tableProductVariants)
        .update({'stock_quantity': stockQuantity}).eq('id', variantId);
  }

  @override
  Future<void> deleteVariant(String variantId) async {
    await _supabase.from(AppConstants.tableProductVariants).delete().eq('id', variantId);
  }

  @override
  Future<ProductImage> uploadImage({
    required String productId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    // Always a fresh path, never an overwrite — same reasoning as trek
    // cover/gallery uploads (avoids serving a stale cached image at an
    // unchanged URL).
    final path = '$productId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _supabase.storage
        .from(AppConstants.bucketMerchImages)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));

    final url = _supabase.storage.from(AppConstants.bucketMerchImages).getPublicUrl(path);

    final row = await _supabase
        .from(AppConstants.tableProductImages)
        .insert({
          'product_id': productId,
          'image_url': url,
        })
        .select()
        .single();

    return ProductImageModel.fromJson(row);
  }

  @override
  Future<void> deleteImage(String id) async {
    try {
      final row = await _supabase
          .from(AppConstants.tableProductImages)
          .select('image_url')
          .eq('id', id)
          .maybeSingle();
      final imageUrl = row?['image_url'] as String?;
      if (imageUrl != null) {
        final path = _extractObjectPath(imageUrl);
        if (path != null) {
          await _supabase.storage.from(AppConstants.bucketMerchImages).remove([path]);
        }
      }
    } catch (_) {
      // Orphaned file at worst — not worth failing the delete over.
    }

    await _supabase.from(AppConstants.tableProductImages).delete().eq('id', id);
  }

  Map<String, dynamic> _writablePayload({
    required String name,
    required String description,
    required double price,
    required ProductCategory category,
    required int stockQuantity,
  }) {
    return {
      'name': name,
      'description': description,
      'price': price,
      'category': category.toDbString(),
      'stock_quantity': stockQuantity,
    };
  }

  /// Extracts the object path from a Supabase Storage public URL
  /// (`.../storage/v1/object/public/{bucket}/{path}`). Returns null if
  /// the URL doesn't match that shape — defensive against a malformed
  /// or manually-edited image_url value.
  String? _extractObjectPath(String publicUrl) {
    const marker = '/object/public/${AppConstants.bucketMerchImages}/';
    final index = publicUrl.indexOf(marker);
    if (index == -1) return null;
    return publicUrl.substring(index + marker.length);
  }
}
