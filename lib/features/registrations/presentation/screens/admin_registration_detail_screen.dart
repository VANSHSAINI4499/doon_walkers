import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Admin detail view for one registration — the only place the sensitive
/// fields (age, gender, emergency contact, medical notes) are rendered.
///
/// They're deliberately kept off the roster list: an at-a-glance screen
/// showing every member's medical notes would expose far more than an
/// organiser needs while scanning, so those require an explicit tap.
///
/// Reachable only via `/admin/registrations/:id`, which `_isAdminRoute`
/// gates in the router. `registrations_select` independently returns
/// nothing here for a non-admin viewing someone else's row.
class AdminRegistrationDetailScreen extends ConsumerWidget {
  const AdminRegistrationDetailScreen({super.key, required this.registrationId});

  final String registrationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final registrationAsync = ref.watch(registrationByIdProvider(registrationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Registration')),
      body: SafeArea(
        child: registrationAsync.when(
          loading: () => const _DetailSkeleton(),
          error: (error, stack) {
            debugPrint('AdminRegistrationDetailScreen: failed to load $registrationId: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(AppIcons.error, size: 40, color: palette.danger),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Could not load this registration.',
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumButton(
                      label: 'Retry',
                      icon: AppIcons.refresh,
                      variant: PremiumButtonVariant.glass,
                      size: PremiumButtonSize.small,
                      onPressed: () => ref.invalidate(registrationByIdProvider(registrationId)),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (registration) {
            if (registration == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Text(
                    'Registration not found.',
                    style: AppTextStyles.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _DetailBody(registration: registration);
          },
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.registration});

  final Registration registration;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _isSaving = false;

  Future<void> _updateStatus(PaymentStatus status) async {
    final r = widget.registration;
    if (status == r.paymentStatus) return;

    final palette = AppPalette.of(context);
    setState(() => _isSaving = true);
    final success = await ref.read(registrationControllerProvider.notifier).setPaymentStatus(
          id: r.id,
          trekId: r.trekId,
          status: status,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!success) {
      final error = ref.read(registrationControllerProvider).error;
      debugPrint('AdminRegistrationDetail: payment_status update failed: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not update payment status. Only administrators can change this.',
          ),
          backgroundColor: palette.danger,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment status set to ${status.label}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.registration;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Who / which trek ────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            r.userName,
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        RegistrationStatusChip(status: r.paymentStatus),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Field(icon: AppIcons.treks, label: 'Trek', value: r.trekTitle),
                    _Field(icon: AppIcons.email, label: 'Email', value: r.userEmail),
                    _Field(
                      icon: AppIcons.call,
                      label: 'Phone',
                      value: r.userPhone,
                      emptyText: 'No phone on file',
                    ),
                    _Field(
                      icon: AppIcons.calendar,
                      label: 'Registered',
                      value: formatRegistrationDate(r.createdAt),
                    ),
                    if (r.paymentStatus == PaymentStatus.cancelled) ...[
                      _Field(
                        icon: AppIcons.info,
                        label: 'Cancellation Reason',
                        value: r.cancellationReason,
                        emptyText: 'No reason specified',
                      ),
                      if (r.cancelledAt != null)
                        _Field(
                          icon: AppIcons.schedule,
                          label: 'Cancelled At',
                          value: formatRegistrationDate(r.cancelledAt!),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Sensitive registrant detail ─────────────────────
              Text(
                'Registrant Details',
                style: AppTextStyles.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Field(
                      icon: AppIcons.birthday,
                      label: 'Age',
                      value: r.age?.toString(),
                      emptyText: 'Not provided',
                    ),
                    _Field(
                      icon: AppIcons.profile,
                      label: 'Gender',
                      value: r.gender?.label,
                      emptyText: 'Not provided',
                    ),
                    _Field(
                      icon: AppIcons.emergencyContact,
                      label: 'Emergency contact',
                      value: r.emergencyContact,
                      emptyText: 'Not provided',
                    ),
                    _Field(
                      icon: AppIcons.medical,
                      label: 'Medical notes',
                      value: r.medicalNotes,
                      emptyText: 'None reported',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Payment proof (only for paid-trek registrations) ─
              if (r.paymentScreenshotUrl != null) ...[
                Text(
                  'Payment Proof',
                  style: AppTextStyles.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                _PaymentProofCard(path: r.paymentScreenshotUrl!),
                const SizedBox(height: AppSpacing.xl),
              ],

              // ── Admin-only payment control ──────────────────────
              Text(
                'Payment Status',
                style: AppTextStyles.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<PaymentStatus>(
                      value: r.paymentStatus,
                      decoration: const InputDecoration(labelText: 'Payment status'),
                      items: PaymentStatus.values
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                          .toList(),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              if (value != null) _updateStatus(value);
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_isSaving)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xs),
                        child: LinearProgressIndicator(),
                      )
                    else
                      Text(
                        'Payments are recorded manually for now — set this once you '
                        'have confirmation from the member.',
                        style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays the member's uploaded payment screenshot for admin review
/// before they mark the registration paid.
class _PaymentProofCard extends ConsumerWidget {
  const _PaymentProofCard({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final signedUrlAsync = ref.watch(paymentProofSignedUrlProvider(path));

    return AppCard(
      padding: EdgeInsets.zero,
      child: signedUrlAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) {
          debugPrint('_PaymentProofCard: failed to sign $path: $error');
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                AppIcon(AppIcons.error, color: palette.danger),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Could not load the payment screenshot.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
                PremiumButton(
                  label: 'Retry',
                  icon: AppIcons.refresh,
                  variant: PremiumButtonVariant.ghost,
                  size: PremiumButtonSize.small,
                  onPressed: () => ref.invalidate(paymentProofSignedUrlProvider(path)),
                ),
              ],
            ),
          );
        },
        data: (signedUrl) => InteractiveViewer(
          child: Image.network(
            signedUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  AppIcon(AppIcons.imageBroken, color: palette.danger),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(child: Text('Could not display the screenshot.')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One labelled field. Renders [emptyText] in muted italics when [value]
/// is null, so a blank never looks like a rendering fault.
class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    this.emptyText,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isEmpty = value == null || value!.trim().isEmpty;
    final display = isEmpty ? (emptyText ?? '—') : value!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 18, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.secondary(AppTextStyles.labelSmall),
                ),
                const SizedBox(height: 2),
                Text(
                  display,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                    color: isEmpty ? palette.textDisabled : palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Shimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: palette.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 180, height: 20),
                      SizedBox(height: AppSpacing.md),
                      SkeletonBox(width: 240, height: 14),
                      SizedBox(height: AppSpacing.sm),
                      SkeletonBox(width: 200, height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
