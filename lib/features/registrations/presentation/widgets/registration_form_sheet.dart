import 'dart:typed_data';

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
/// section's presence depends on it: [Trek.requiresPayment]. A free
/// trek (`registrationFee == 0`) shows none of the payment UI at all —
/// not even a zeroed-out section — per the Part C brief.
///
/// Returns true when a registration was created, so the caller can show
/// a confirmation.
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
  /// about after the admin's actually tried to submit, same as the
  /// gender dropdown below (no live-validate-while-typing noise).
  bool _showScreenshotRequiredError = false;

  @override
  void dispose() {
    _ageController.dispose();
    _emergencyContactController.dispose();
    _medicalNotesController.dispose();
    super.dispose();
  }

  /// Mirrors the `registrations_age_check` CHECK constraint
  /// (`age > 0 AND age < 120`) so an out-of-range value is caught here
  /// with a readable message rather than coming back as a raw constraint
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

    // Required screenshot upload before submission is allowed, for a
    // paid trek — same "check explicitly, no FormField wrapper" pattern
    // as gender above, since an image picker isn't a Form-validatable
    // field type.
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

  /// Keeps raw Postgres/Storage detail out of the UI while still giving
  /// the duplicate and screenshot-upload cases their own actionable
  /// messages.
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
    final theme = Theme.of(context);
    final isSaving = ref.watch(registrationControllerProvider).isLoading;

    ref.listen<AsyncValue<void>>(registrationControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage(error)),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        },
      );
    });

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Register for this trek',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.trek.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: _validateAge,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<GenderType>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: GenderType.values
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.label)))
                    .toList(),
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: 16),

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
              const SizedBox(height: 16),

              TextFormField(
                controller: _medicalNotesController,
                decoration: const InputDecoration(
                  labelText: 'Medical notes (optional)',
                  hintText: 'Allergies, conditions, medication — anything the trek lead should know',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              Text(
                'Only you and the Doon Walkers organisers can see these details.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              // Payment section — entirely absent for a free trek, per
              // the Part C brief ("skip this section entirely").
              if (widget.trek.requiresPayment) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _PaymentSection(
                  fee: widget.trek.registrationFee,
                  qrCodeUrl: widget.trek.paymentQrCode,
                  screenshotBytes: _screenshotBytes,
                  showRequiredError: _showScreenshotRequiredError,
                  onPickScreenshot: _pickScreenshot,
                ),
              ],

              const SizedBox(height: 20),

              FilledButton(
                onPressed: isSaving ? null : _submit,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm Registration'),
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.currency_rupee_rounded, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Registration fee: ₹${_formatFee(fee)}',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (qrCodeUrl != null && qrCodeUrl!.isNotEmpty) ...[
          Text(
            'Scan to pay',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              qrCodeUrl!,
              height: 220,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Container(
                height: 120,
                alignment: Alignment.center,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.outline),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text(
          'Upload payment screenshot',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPickScreenshot,
          child: Container(
            height: 160,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: showRequiredError
                    ? theme.colorScheme.error
                    : theme.colorScheme.outlineVariant,
                width: showRequiredError ? 2 : 1,
              ),
            ),
            child: screenshotBytes != null
                ? Image.memory(screenshotBytes!, fit: BoxFit.cover, width: double.infinity)
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 32,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to add your payment screenshot',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (showRequiredError) ...[
          const SizedBox(height: 6),
          Text(
            'Please upload proof of payment before confirming.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}
