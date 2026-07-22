/// Maps 1-to-1 with the `merch_inquiry_status` enum in Postgres
/// (`pending`, `contacted`, `fulfilled`, `cancelled`) — see
/// 0018_merch_inquiries.sql.
enum MerchInquiryStatus {
  pending,
  contacted,
  fulfilled,
  cancelled;

  /// Matches the Dart enum's identifier name exactly to the Postgres
  /// enum value — deliberately kept 1:1 so `.name` round-trips safely.
  static MerchInquiryStatus fromString(String? value) {
    return MerchInquiryStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => MerchInquiryStatus.pending, // matches the DB column default
    );
  }

  String toDbString() => name;

  String get label => switch (this) {
    MerchInquiryStatus.pending => 'Pending',
    MerchInquiryStatus.contacted => 'Contacted',
    MerchInquiryStatus.fulfilled => 'Fulfilled',
    MerchInquiryStatus.cancelled => 'Cancelled',
  };
}

/// Core domain representation of a row in `public.merch_inquiries`,
/// with the joined display fields the admin roster needs (who asked,
/// about what product/size) — see MerchInquiryRepository's select shape.
///
/// This is admin-facing only in this phase: there is no member-facing
/// "my past inquiries" list yet, only the submit flow — see
/// [MerchInquiryRepository]'s doc.
class MerchInquiry {
  final String id;
  final String userId;
  final String productId;
  final String? variantId;
  final int quantity;
  final String? note;
  final MerchInquiryStatus status;
  final DateTime createdAt;

  /// Joined from `public.products`.
  final String productName;

  /// Joined from `public.product_variants`, null when [variantId] is
  /// null (a one-size product) or the referenced variant has since
  /// been deleted (ON DELETE SET NULL — see the migration).
  final String? variantSize;

  /// Joined from `public.users` — how the admin follows up.
  final String userName;
  final String userEmail;
  final String? userPhone;

  const MerchInquiry({
    required this.id,
    required this.userId,
    required this.productId,
    this.variantId,
    required this.quantity,
    this.note,
    required this.status,
    required this.createdAt,
    required this.productName,
    this.variantSize,
    required this.userName,
    required this.userEmail,
    this.userPhone,
  });
}
