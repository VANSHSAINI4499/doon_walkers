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
    final theme = Theme.of(context);
    final (bg, fg) = switch (status) {
      MerchInquiryStatus.fulfilled => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
        ),
      MerchInquiryStatus.pending || MerchInquiryStatus.contacted => (
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
        ),
      MerchInquiryStatus.cancelled => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.label,
        style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }
}
