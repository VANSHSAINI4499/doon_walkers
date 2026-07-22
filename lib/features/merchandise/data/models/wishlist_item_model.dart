import 'package:doon_walkers/features/merchandise/data/models/product_model.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/wishlist_item.dart';

/// Data model representing a row in `public.user_wishlist`, extending
/// [WishlistItem] with JSON deserialization — including its embedded
/// `products(*, product_images(*))` join, parsed via the existing
/// [ProductModel.fromJson] rather than duplicating product-parsing
/// logic here.
class WishlistItemModel extends WishlistItem {
  const WishlistItemModel({
    required super.id,
    required super.userId,
    required super.productId,
    required super.createdAt,
    required super.product,
  });

  factory WishlistItemModel.fromJson(Map<String, dynamic> json) {
    return WishlistItemModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      productId: json['product_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      product: ProductModel.fromJson(json['products'] as Map<String, dynamic>),
    );
  }
}
