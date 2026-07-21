import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:flutter/material.dart';

/// Shared `payment_status` pill, used by the admin roster, the admin
/// detail view, and the member's own "My Registrations" list so the same
/// status never renders three slightly different ways.
///
/// [label] overrides the displayed text while [status] still drives the
/// colour — used by member-facing surfaces to show
/// [Registration.memberFacingStatusLabel] ("Pending Verification")
/// instead of the generic admin-facing [PaymentStatus.label] ("Pending").
class RegistrationStatusChip extends StatelessWidget {
  const RegistrationStatusChip({super.key, required this.status, this.label});

  final PaymentStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = switch (status) {
      PaymentStatus.paid => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
        ),
      PaymentStatus.pending => (
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
        ),
      PaymentStatus.refunded || PaymentStatus.cancelled => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label ?? status.label,
        style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Shared date formatting for registration timestamps, so the member and
/// admin views agree. Converts to local time first — `created_at` is
/// `timestamptz` and arrives as UTC.
String formatRegistrationDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = dt.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
