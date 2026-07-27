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
      itemBuilder:
          (registration) => MyRegistrationTile(registration: registration),
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

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder:
          (sheetContext) => _CancellationReasonSheet(trekTitle: r.trekTitle),
    );

    if (reason == null || !mounted) return;

    setState(() => _isPending = true);
    final success = await ref
        .read(registrationControllerProvider.notifier)
        .cancel(id: r.id, trekId: r.trekId, reason: reason);
    if (!mounted) return;
    setState(() => _isPending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Registration cancelled.'
              : 'Could not cancel your registration. Please try again.',
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
                  style: AppTextStyles.titleSmall.copyWith(
                    color: palette.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // A free-trek registration shows no payment_status badge —
              // "nothing to verify" — per the Part C brief.
              if (r.involvedPayment) ...[
                const SizedBox(width: AppSpacing.sm),
                RegistrationStatusChip(
                  status: r.paymentStatus,
                  label: r.memberFacingStatusLabel,
                ),
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
              if (group == RegistrationStatusGroup.completed &&
                  r.checkedInAt != null)
                _MetaLine(
                  icon: AppIcons.verified,
                  text: 'Checked in',
                  palette: palette,
                  tint: palette.primary,
                ),
            ],
          ),
          if (group == RegistrationStatusGroup.upcoming) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child:
                  _isPending
                      ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.danger,
                          ),
                        ),
                      )
                      : TextButton.icon(
                        onPressed: _confirmCancel,
                        icon: AppIcon(
                          AppIcons.close,
                          size: 18,
                          color: palette.danger,
                        ),
                        label: Text(
                          'Cancel registration',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: palette.danger,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
            ),
          ],
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

class _CancellationReasonSheet extends StatefulWidget {
  const _CancellationReasonSheet({required this.trekTitle});
  final String trekTitle;

  @override
  State<_CancellationReasonSheet> createState() =>
      _CancellationReasonSheetState();
}

class _CancellationReasonSheetState extends State<_CancellationReasonSheet> {
  final _reasons = [
    'Change of plans',
    'Health / personal reasons',
    'Transport issues',
    'Found a better option',
    'Other (please specify)',
  ];

  String? _selectedReason;
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isOther = _selectedReason == 'Other (please specify)';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cancel Registration?',
                style: AppTextStyles.titleMedium.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'This will cancel your spot for "${widget.trekTitle}". This action is irreversible.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ..._reasons.map((reason) {
                return RadioListTile<String>(
                  title: Text(
                    reason,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (val) {
                    setState(() => _selectedReason = val);
                  },
                  activeColor: palette.primary,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }),
              if (isOther) ...[
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: 'Specify reason',
                    hintText: 'Describe why you are cancelling...',
                  ),
                  maxLength: 200,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please specify a reason';
                    }
                    if (value.trim().length > 200) {
                      return 'Reason must be 200 characters or less';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Keep spot',
                      variant: AppButtonVariant.glass,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Yes, cancel spot',
                      variant: AppButtonVariant.danger,
                      onPressed:
                          _selectedReason == null
                              ? null
                              : () {
                                if (isOther &&
                                    !_formKey.currentState!.validate()) {
                                  return;
                                }
                                final finalReason =
                                    isOther
                                        ? _textController.text.trim()
                                        : _selectedReason!;
                                Navigator.pop(context, finalReason);
                              },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
