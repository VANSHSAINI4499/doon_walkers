import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';

/// Core domain representation of a row in `public.user_wishlist`,
/// carrying the joined [product] it points to — "My Wishlist" on
/// Profile only ever needs the product's display fields (name, price,
/// cover image), never a bare id, so the join happens at the
/// repository layer rather than requiring a second fetch per item.
class WishlistItem {
  final String id;
  final String userId;
  final String productId;
  final DateTime createdAt;
  final Product product;

  const WishlistItem({
    required this.id,
    required this.userId,
    required this.productId,
    required this.createdAt,
    required this.product,
  });
}
