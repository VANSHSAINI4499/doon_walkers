import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the trek registration form as a modal sheet over Trek Detail.
///
/// The trek and the user are implicit — the trek from the screen that
/// launched this, the user from the live Supabase session — so the form
/// only asks for what it genuinely can't infer.
///
/// Returns true when a registration was created, so the caller can show
/// a confirmation.
Future<bool?> showRegistrationFormSheet(
  BuildContext context, {
  required String trekId,
  required String trekTitle,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _RegistrationFormSheet(
      trekId: trekId,
      trekTitle: trekTitle,
    ),
  );
}

class _RegistrationFormSheet extends ConsumerStatefulWidget {
  const _RegistrationFormSheet({required this.trekId, required this.trekTitle});

  final String trekId;
  final String trekTitle;

  @override
  ConsumerState<_RegistrationFormSheet> createState() => _RegistrationFormSheetState();
}

class _RegistrationFormSheetState extends ConsumerState<_RegistrationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _medicalNotesController = TextEditingController();

  GenderType? _gender;

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

    final medicalNotes = _medicalNotesController.text.trim();
    final created = await ref.read(registrationControllerProvider.notifier).register(
          trekId: widget.trekId,
          age: int.parse(_ageController.text.trim()),
          gender: gender,
          emergencyContact: _emergencyContactController.text.trim(),
          medicalNotes: medicalNotes.isEmpty ? null : medicalNotes,
        );

    if (!mounted || created == null) return;
    Navigator.of(context).pop(true);
  }

  /// Keeps raw Postgres detail out of the UI while still giving the
  /// duplicate case its own actionable message.
  String _errorMessage(Object error) {
    debugPrint('RegistrationFormSheet: registration failed: $error');
    if (error is DuplicateRegistrationException) {
      return "You're already registered for this trek.";
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
                widget.trekTitle,
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
