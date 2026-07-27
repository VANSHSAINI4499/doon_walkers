import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:flutter/material.dart';

/// Shared `status` pill for a merchandise inquiry — mirrors
/// [RegistrationStatusChip]'s tinted-container treatment so the two
/// analogous "admin follows up on a member-submitted row" flows read
/// consistently.
class MerchInquiryStatusChip extends StatelessWidget {
  const MerchInquiryStatusChip({super.key, required this.status});

  final MerchInquiryStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final (bg, fg) = switch (status) {
      MerchInquiryStatus.fulfilled => (
        palette.primaryContainer,
        palette.onPrimaryContainer,
      ),
      MerchInquiryStatus.pending || MerchInquiryStatus.contacted => (
        palette.accentContainer,
        palette.onAccent,
      ),
      MerchInquiryStatus.cancelled => (palette.cardHigh, palette.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.tinted(AppTextStyles.labelSmall, fg),
      ),
    );
  }
}
