import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/preview_section.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel registration?'),
        content: Text(
          'This removes your registration for "${r.trekTitle}". '
          'You can register again later if spots are still open.',
        ),
        actions: [
          PremiumButton(
            label: 'Keep it',
            variant: PremiumButtonVariant.glass,
            size: PremiumButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PremiumButton(
            label: 'Cancel registration',
            variant: PremiumButtonVariant.danger,
            size: PremiumButtonSize.small,
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
        backgroundColor: success ? null : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.registration;

    return GlassCard(
      blurEnabled: false,
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
                  style: AppTextStyles.titleSmall,
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
          Text(
            'Registered ${formatRegistrationDate(r.createdAt)}',
            style: AppTextStyles.secondary(AppTextStyles.bodySmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: _isPending
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _confirmCancel,
                    icon: const AppIcon(AppIcons.close, size: 18, color: AppColors.danger),
                    label: Text(
                      'Cancel registration',
                      style: AppTextStyles.tinted(AppTextStyles.labelMedium, AppColors.danger),
                    ),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
          ),
        ],
      ),
    );
  }
}
