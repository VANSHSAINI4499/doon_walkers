import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/preview_section.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/domain/services/registration_status_group.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "My Registrations" on Profile — a dashboard preview of the
/// signed-in user's 2 most recent trek registrations, with
/// self-service cancellation and a "View All" link to
/// [MyRegistrationsScreen] once there are more than 2.
///
/// **The behaviour is unchanged:** scoped by [myRegistrationsPreviewProvider]
/// (+ `registrations_select` RLS), and cancelling still DELETEs the row
/// (the admin-only `payment_status` column and its
/// `prevent_payment_status_self_edit` trigger are untouched), behind
/// the same confirmation dialog.
class MyRegistrationsSection extends ConsumerWidget {
  const MyRegistrationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrationsAsync = ref.watch(myRegistrationsPreviewProvider);

    return PreviewSection<Registration>(
      title: 'My Registrations',
      icon: AppIcons.ticket,
      asyncItems: registrationsAsync,
      itemBuilder: (registration) => MyRegistrationTile(registration: registration),
      onViewAll: () => context.push(AppConstants.routeMyRegistrations),
      onRetry: () => ref.invalidate(myRegistrationsPreviewProvider),
      errorMessage: 'Could not load your registrations.',
      emptyIcon: AppIcons.hiking,
      emptyMessage: "You haven't registered for any treks yet.",
      emptyActionLabel: 'Browse Treks',
      onEmptyAction: () => context.go(AppConstants.routeTrekLibrary),
    );
  }
}

/// One registration row — shared by [MyRegistrationsSection]'s preview
/// and [MyRegistrationsScreen]'s full list.
///
/// Redesign 2.0 Phase 15 restyles this calm and adds the trek's scheduled
/// date (real — [Registration.trekDate], already joined) alongside the
/// existing "Registered on" line. It does **not** add duration or a
/// location name: neither is joined onto a registration row (only
/// `trek_date` and `title` are — see `RegistrationRepositoryImpl`'s
/// `treks(title, trek_date)` select), so a card here can't show what a
/// Trek Library/Detail card can.
class MyRegistrationTile extends ConsumerStatefulWidget {
  const MyRegistrationTile({super.key, required this.registration});

  final Registration registration;

  @override
  ConsumerState<MyRegistrationTile> createState() => _MyRegistrationTileState();
}

class _MyRegistrationTileState extends ConsumerState<MyRegistrationTile> {
  bool _isPending = false;

  Future<void> _confirmCancel() async {
    final r = widget.registration;
    final palette = AppPalette.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel registration?'),
        content: Text(
          'This removes your registration for "${r.trekTitle}". '
          'You can register again later if spots are still open.',
        ),
        actions: [
          AppButton(
            label: 'Keep it',
            variant: AppButtonVariant.glass,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton(
            label: 'Cancel registration',
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isPending = true);
    final success = await ref
        .read(registrationControllerProvider.notifier)
        .cancel(id: r.id, trekId: r.trekId);
    if (!mounted) return;
    setState(() => _isPending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Registration cancelled.' : 'Could not cancel your registration. Please try again.',
        ),
        backgroundColor: success ? null : palette.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final r = widget.registration;
    final group = registrationStatusGroupFor(r);
    final trekDate = r.trekDate;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  r.trekTitle,
                  style: AppTextStyles.titleSmall.copyWith(color: palette.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // A free-trek registration shows no payment_status badge —
              // "nothing to verify" — per the Part C brief.
              if (r.involvedPayment) ...[
                const SizedBox(width: AppSpacing.sm),
                RegistrationStatusChip(status: r.paymentStatus, label: r.memberFacingStatusLabel),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              if (trekDate != null)
                _MetaLine(
                  icon: AppIcons.calendar,
                  text: formatRegistrationDate(trekDate),
                  palette: palette,
                ),
              _MetaLine(
                icon: AppIcons.eventAvailable,
                text: 'Registered ${formatRegistrationDate(r.createdAt)}',
                palette: palette,
              ),
              // Only meaningful once the trek has actually happened — a
              // silent no-op for an upcoming/cancelled registration, since
              // checkedInAt can't be set yet either way.
              if (group == RegistrationStatusGroup.completed && r.checkedInAt != null)
                _MetaLine(
                  icon: AppIcons.verified,
                  text: 'Checked in',
                  palette: palette,
                  tint: palette.primary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: _isPending
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: palette.danger),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _confirmCancel,
                    icon: AppIcon(AppIcons.close, size: 18, color: palette.danger),
                    label: Text(
                      'Cancel registration',
                      style: AppTextStyles.labelMedium.copyWith(color: palette.danger),
                    ),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    required this.palette,
    this.tint,
  });

  final IconData icon;
  final String text;
  final AppPalette palette;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? palette.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(text, style: AppTextStyles.bodySmall.copyWith(color: color)),
      ],
    );
  }
}
