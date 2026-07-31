import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_status_chip.dart';
import 'package:flutter/material.dart';

/// One registration row — shared by [AdminRegistrationsScreen] (the
/// cross-trek roster) and the per-trek roster (Admin Dashboard → Trek
/// Registrations), rather than each screen keeping its own copy.
///
/// [showTrekTitle] defaults to true for the cross-trek roster, where the
/// trek name is the thing that tells rows apart. The per-trek roster
/// passes false — every row is already the same trek (its name is the
/// screen's AppBar title), so repeating it on every tile would be noise.
class RegistrationTile extends StatelessWidget {
  const RegistrationTile({
    super.key,
    required this.registration,
    required this.onTap,
    this.showTrekTitle = true,
  });

  final Registration registration;
  final VoidCallback onTap;
  final bool showTrekTitle;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final r = registration;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  r.userName,
                  style: AppTextStyles.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              RegistrationStatusChip(
                status: r.paymentStatus,
                isFreeTrek: r.isFreeTrek,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (showTrekTitle) ...[
            _DetailRow(icon: AppIcons.treks, text: r.trekTitle),
            const SizedBox(height: AppSpacing.xs),
          ],
          _DetailRow(icon: AppIcons.email, text: r.userEmail),
          const SizedBox(height: AppSpacing.xs),
          // Phone is nullable in the schema — say so plainly rather than
          // rendering an empty row that looks like a rendering bug.
          _DetailRow(
            icon: AppIcons.call,
            text: r.userPhone ?? 'No phone on file',
            muted: r.userPhone == null,
          ),
          if (r.paymentStatus == PaymentStatus.cancelled &&
              r.cancellationReason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _DetailRow(
              icon: AppIcons.info,
              text: 'Reason: ${r.cancellationReason}',
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _DetailRow(
                  icon: AppIcons.calendar,
                  text: 'Registered ${formatRegistrationDate(r.createdAt)}',
                ),
              ),
              AppIcon(
                AppIcons.chevronRight,
                size: 20,
                color: palette.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      children: [
        AppIcon(icon, size: 16, color: palette.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.secondary(
              AppTextStyles.bodySmall,
            ).copyWith(fontStyle: muted ? FontStyle.italic : FontStyle.normal),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
