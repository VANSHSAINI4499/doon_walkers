import 'dart:typed_data';

import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the trek registration form as a modal sheet over Trek Detail.
///
/// The trek and the user are implicit — the trek from the screen that
/// launched this, the user from the live Supabase session — so the form
/// only asks for what it genuinely can't infer.
///
/// Takes the whole [trek] (not just id/title) because the payment
/// section's presence depends on it: [Trek.requiresPayment]. A free trek
/// (`registrationFee == 0`) shows none of the payment UI at all — not even
/// a zeroed-out section — per the Part C brief.
///
/// Returns true when a registration was created, so the caller can show a
/// confirmation.
///
/// Redesign Phase 3 restyles this sheet onto the design system. All of its
/// logic is unchanged: the age CHECK-mirroring validator, the explicit
/// gender check, the paid-trek screenshot-required guard, the submit path,
/// and the error mapping.
Future<bool?> showRegistrationFormSheet(BuildContext context, {required Trek trek}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _RegistrationFormSheet(trek: trek),
  );
}

class _RegistrationFormSheet extends ConsumerStatefulWidget {
  const _RegistrationFormSheet({required this.trek});

  final Trek trek;

  @override
  ConsumerState<_RegistrationFormSheet> createState() => _RegistrationFormSheetState();
}

class _RegistrationFormSheetState extends ConsumerState<_RegistrationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _medicalNotesController = TextEditingController();

  GenderType? _gender;

  // ── Payment (only used when widget.trek.requiresPayment) ───────────
  Uint8List? _screenshotBytes;
  String? _screenshotExtension;

  /// Set once, on submit — screenshot-missing is only worth complaining
  /// about after the user's actually tried to submit, same as the gender
  /// dropdown below (no live-validate-while-typing noise).
  bool _showScreenshotRequiredError = false;

  @override
  void dispose() {
    _ageController.dispose();
    _emergencyContactController.dispose();
    _medicalNotesController.dispose();
    super.dispose();
  }

  /// Mirrors the `registrations_age_check` CHECK constraint
  /// (`age > 0 AND age < 120`) so an out-of-range value is caught here with
  /// a readable message rather than coming back as a raw constraint
  /// violation from Postgres.
  String? _validateAge(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your age';
    final age = int.tryParse(text);
    if (age == null) return 'Please enter a valid number';
    if (age <= 0 || age >= 120) return 'Please enter an age between 1 and 119';
    return null;
  }

  static const _allowedScreenshotExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  Future<void> _pickScreenshot() async {
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (xfile == null) return;

    final parts = xfile.name.split('.');
    final extension = parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
    if (!_allowedScreenshotExtensions.contains(extension)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose a JPG, PNG, or WEBP image.')),
        );
      }
      return;
    }

    final bytes = await xfile.readAsBytes();
    if (!mounted) return;
    setState(() {
      _screenshotBytes = bytes;
      _screenshotExtension = extension;
      _showScreenshotRequiredError = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Dropdown has no validator of its own — check it explicitly.
    final gender = _gender;
    if (gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a gender option.')),
      );
      return;
    }

    // Required screenshot upload before submission is allowed, for a paid
    // trek — same "check explicitly, no FormField wrapper" pattern as
    // gender above, since an image picker isn't a Form-validatable field
    // type.
    if (widget.trek.requiresPayment && _screenshotBytes == null) {
      setState(() => _showScreenshotRequiredError = true);
      return;
    }

    final medicalNotes = _medicalNotesController.text.trim();
    final created = await ref.read(registrationControllerProvider.notifier).register(
          trek: widget.trek,
          age: int.parse(_ageController.text.trim()),
          gender: gender,
          emergencyContact: _emergencyContactController.text.trim(),
          medicalNotes: medicalNotes.isEmpty ? null : medicalNotes,
          paymentScreenshotBytes: _screenshotBytes,
          paymentScreenshotExtension: _screenshotExtension,
        );

    if (!mounted || created == null) return;
    Navigator.of(context).pop(true);
  }

  /// Keeps raw Postgres/Storage detail out of the UI while still giving the
  /// duplicate and screenshot-upload cases their own actionable messages.
  String _errorMessage(Object error) {
    debugPrint('RegistrationFormSheet: registration failed: $error');
    if (error is DuplicateRegistrationException) {
      return "You're already registered for this trek.";
    }
    if (error is PaymentScreenshotUploadException) {
      return error.toString();
    }
    if (error is TrekRegistrationClosedException) {
      return error.toString();
    }
    return 'Could not complete your registration. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(registrationControllerProvider).isLoading;

    ref.listen<AsyncValue<void>>(registrationControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage(error)),
              backgroundColor: AppColors.danger,
            ),
          );
        },
      );
    });

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const AppIcon(AppIcons.hiking, size: 20, color: AppColors.onPrimary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Register for this trek', style: AppTextStyles.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          widget.trek.title,
                          style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: _validateAge,
              ),
              const SizedBox(height: AppSpacing.lg),

              DropdownButtonFormField<GenderType>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: GenderType.values
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.label)))
                    .toList(),
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(
                  labelText: 'Emergency contact',
                  hintText: 'Name and phone number',
                ),
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please provide an emergency contact'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                controller: _medicalNotesController,
                decoration: const InputDecoration(
                  labelText: 'Medical notes (optional)',
                  hintText: 'Allergies, conditions, medication — anything the trek lead should know',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  const AppIcon(AppIcons.lock, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Only you and the Doon Walkers organisers can see these details.',
                      style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                    ),
                  ),
                ],
              ),

              // Payment section — entirely absent for a free trek, per the
              // Part C brief ("skip this section entirely").
              if (widget.trek.requiresPayment) ...[
                const SizedBox(height: AppSpacing.xl),
                _PaymentSection(
                  fee: widget.trek.registrationFee,
                  qrCodeUrl: widget.trek.paymentQrCode,
                  screenshotBytes: _screenshotBytes,
                  showRequiredError: _showScreenshotRequiredError,
                  onPickScreenshot: _pickScreenshot,
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              PremiumButton(
                label: 'Confirm Registration',
                icon: AppIcons.checkCircle,
                size: PremiumButtonSize.large,
                fullWidth: true,
                isLoading: isSaving,
                onPressed: isSaving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.fee,
    required this.qrCodeUrl,
    required this.screenshotBytes,
    required this.showRequiredError,
    required this.onPickScreenshot,
  });

  final double fee;
  final String? qrCodeUrl;
  final Uint8List? screenshotBytes;
  final bool showRequiredError;
  final VoidCallback onPickScreenshot;

  String _formatFee(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurEnabled: false,
      glowColor: AppColors.gold,
      glowOpacity: 0.12,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const AppIcon(AppIcons.payment, size: 18, color: AppColors.gold),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Registration fee', style: AppTextStyles.secondary(AppTextStyles.bodySmall)),
                    Text(
                      '₹${_formatFee(fee)}',
                      style: AppTextStyles.tinted(AppTextStyles.statSmall, AppColors.gold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (qrCodeUrl != null && qrCodeUrl!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Scan to pay', style: AppTextStyles.secondary(AppTextStyles.bodySmall)),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.network(
                  qrCodeUrl!,
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => Container(
                    height: 120,
                    width: 120,
                    alignment: Alignment.center,
                    color: AppColors.cardHigh,
                    child: const AppIcon(AppIcons.imageBroken, color: AppColors.textDisabled),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          Text('Upload payment screenshot', style: AppTextStyles.secondary(AppTextStyles.bodySmall)),
          const SizedBox(height: AppSpacing.sm),
          Pressable(
            onTap: onPickScreenshot,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              height: 160,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                color: AppColors.surface,
                border: Border.all(
                  color: showRequiredError ? AppColors.danger : AppColors.glassBorder,
                  width: showRequiredError ? 2 : 1,
                ),
              ),
              child: screenshotBytes != null
                  ? Image.memory(screenshotBytes!, fit: BoxFit.cover, width: double.infinity)
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(AppIcons.addPhoto, size: 32, color: AppColors.textSecondary),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            'Tap to add your payment screenshot',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          if (showRequiredError) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Please upload proof of payment before confirming.',
              style: AppTextStyles.tinted(AppTextStyles.bodySmall, AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}
