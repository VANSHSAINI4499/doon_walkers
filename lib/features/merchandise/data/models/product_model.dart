import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';

/// Data model representing a row in `public.product_variants`,
/// extending [ProductVariant] with JSON deserialization.
class ProductVariantModel extends ProductVariant {
  const ProductVariantModel({
    required super.id,
    required super.productId,
    required super.size,
    required super.stockQuantity,
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    return ProductVariantModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      size: (json['size'] as String?) ?? '',
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Data model representing a row in `public.product_images`, extending
/// [ProductImage] with JSON deserialization.
class ProductImageModel extends ProductImage {
  const ProductImageModel({
    required super.id,
    required super.productId,
    required super.imageUrl,
    required super.uploadedAt,
  });

  factory ProductImageModel.fromJson(Map<String, dynamic> json) {
    return ProductImageModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      imageUrl: (json['image_url'] as String?) ?? '',
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'] as String)
          : DateTime.now(),
    );
  }
}

/// Data model representing a row in `public.products`, extending
/// [Product] with JSON deserialization from a Supabase/PostgREST row —
/// including its nested `product_variants(*)`/`product_images(*)`
/// joins (see ProductRepositoryImpl's `.select()` shape).
class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    required super.description,
    required super.price,
    required super.category,
    required super.stockQuantity,
    required super.isActive,
    required super.createdAt,
    super.variants,
    super.images,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final variantRows = (json['product_variants'] as List?) ?? const [];
    final imageRows = (json['product_images'] as List?) ?? const [];

    final images = imageRows
        .map((row) => ProductImageModel.fromJson(row as Map<String, dynamic>))
        .toList()
      // Oldest first — see Product.coverImageUrl's doc for why this
      // ordering matters (stable thumbnail regardless of fetch order).
      ..sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));

    return ProductModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      // Postgres numeric arrives as a String or num depending on
      // driver — handle both defensively (same pattern as
      // TrekModel.registrationFee).
      price: switch (json['price']) {
        null => 0,
        final num n => n.toDouble(),
        final Object v => double.tryParse(v.toString()) ?? 0,
      },
      category: ProductCategory.fromString(json['category'] as String?),
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      variants: variantRows
          .map((row) => ProductVariantModel.fromJson(row as Map<String, dynamic>))
          .toList(),
      images: images,
    );
  }
}
