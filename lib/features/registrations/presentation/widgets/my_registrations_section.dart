import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/glass_states.dart';
import 'package:doon_walkers/core/widgets/section_title.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "My Registrations" on Profile — the signed-in user's own registered
/// treks, with self-service cancellation.
///
/// Redesign Phase 5 restyles this onto the design system. **The behaviour
/// is unchanged:** scoped by [myRegistrationsProvider] (+ `registrations_
/// select` RLS), and cancelling still DELETEs the row (the admin-only
/// `payment_status` column and its `prevent_payment_status_self_edit`
/// trigger are untouched), behind the same confirmation dialog.
class MyRegistrationsSection extends ConsumerWidget {
  const MyRegistrationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrationsAsync = ref.watch(myRegistrationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(title: 'My Registrations', icon: AppIcons.ticket),
        const SizedBox(height: AppSpacing.md),
        registrationsAsync.when(
          loading: () => const SkeletonList(count: 2, showImages: false, padding: EdgeInsets.zero),
          error: (error, stack) {
            debugPrint('MyRegistrationsSection: failed to load registrations: $error');
            return GlassSectionError(
              message: 'Could not load your registrations.',
              onRetry: () => ref.invalidate(myRegistrationsProvider),
            );
          },
          data: (registrations) {
            if (registrations.isEmpty) return const _EmptyMyRegistrations();
            return Column(
              children: [
                for (final registration in registrations) ...[
                  _MyRegistrationTile(registration: registration),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EmptyMyRegistrations extends StatelessWidget {
  const _EmptyMyRegistrations();

  @override
  Widget build(BuildContext context) {
    return GlassEmptyState(
      icon: AppIcons.hiking,
      message: "You haven't registered for any treks yet.",
      actionLabel: 'Browse Treks',
      onAction: () => context.go(AppConstants.routeTrekLibrary),
    );
  }
}

class _MyRegistrationTile extends ConsumerStatefulWidget {
  const _MyRegistrationTile({required this.registration});

  final Registration registration;

  @override
  ConsumerState<_MyRegistrationTile> createState() => _MyRegistrationTileState();
}

class _MyRegistrationTileState extends ConsumerState<_MyRegistrationTile> {
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

