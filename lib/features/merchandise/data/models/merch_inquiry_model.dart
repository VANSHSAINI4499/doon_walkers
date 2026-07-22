import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';

/// Data model representing a row in `public.merch_inquiries`, extending
/// [MerchInquiry] with JSON deserialization from a Supabase/PostgREST
/// row — including its embedded `products(name)`, `product_variants(size)`,
/// and `users(name, email, phone)` joins (see
/// MerchInquiryRepositoryImpl's `.select()` shape).
class MerchInquiryModel extends MerchInquiry {
  const MerchInquiryModel({
    required super.id,
    required super.userId,
    required super.productId,
    super.variantId,
    required super.quantity,
    super.note,
    required super.status,
    required super.createdAt,
    required super.productName,
    super.variantSize,
    required super.userName,
    required super.userEmail,
    super.userPhone,
  });

  factory MerchInquiryModel.fromJson(Map<String, dynamic> json) {
    final product = json['products'] as Map<String, dynamic>?;
    final variant = json['product_variants'] as Map<String, dynamic>?;
    final user = json['users'] as Map<String, dynamic>?;

    return MerchInquiryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      note: json['note'] as String?,
      status: MerchInquiryStatus.fromString(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      productName: (product?['name'] as String?) ?? '',
      variantSize: variant?['size'] as String?,
      userName: (user?['name'] as String?) ?? '',
      userEmail: (user?['email'] as String?) ?? '',
      userPhone: user?['phone'] as String?,
    );
  }
}
