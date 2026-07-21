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
    final theme = Theme.of(context);
    final registrationAsync = ref.watch(registrationByIdProvider(registrationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Registration')),
      body: SafeArea(
        child: registrationAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('AdminRegistrationDetailScreen: failed to load $registrationId: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load this registration.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(registrationByIdProvider(registrationId)),
                      child: const Text('Retry'),
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
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Registration not found.',
                    style: theme.textTheme.titleMedium,
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

    setState(() => _isSaving = true);
    final success = await ref.read(registrationControllerProvider.notifier).setPaymentStatus(
          id: r.id,
          trekId: r.trekId,
          status: status,
        );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!success) {
      // The prevent_payment_status_self_edit trigger raises for any
      // non-admin caller, so a failure here most likely means the
      // session isn't actually an admin — say something useful rather
      // than a bare retry prompt.
      final error = ref.read(registrationControllerProvider).error;
      debugPrint('AdminRegistrationDetail: payment_status update failed: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not update payment status. Only administrators can change this.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
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
    final theme = Theme.of(context);
    final r = widget.registration;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Who / which trek ────────────────────────────────
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              r.userName,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          RegistrationStatusChip(status: r.paymentStatus),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Field(icon: Icons.terrain_rounded, label: 'Trek', value: r.trekTitle),
                      _Field(icon: Icons.email_outlined, label: 'Email', value: r.userEmail),
                      _Field(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: r.userPhone,
                        emptyText: 'No phone on file',
                      ),
                      _Field(
                        icon: Icons.event_outlined,
                        label: 'Registered',
                        value: formatRegistrationDate(r.createdAt),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Sensitive registrant detail ─────────────────────
              Text(
                'Registrant Details',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Field(
                        icon: Icons.cake_outlined,
                        label: 'Age',
                        value: r.age?.toString(),
                        emptyText: 'Not provided',
                      ),
                      _Field(
                        icon: Icons.person_outline,
                        label: 'Gender',
                        value: r.gender?.label,
                        emptyText: 'Not provided',
                      ),
                      _Field(
                        icon: Icons.contact_emergency_outlined,
                        label: 'Emergency contact',
                        value: r.emergencyContact,
                        emptyText: 'Not provided',
                      ),
                      _Field(
                        icon: Icons.medical_information_outlined,
                        label: 'Medical notes',
                        value: r.medicalNotes,
                        emptyText: 'None reported',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Admin-only payment control ──────────────────────
              Text(
                'Payment Status',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 10),
                      if (_isSaving)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: LinearProgressIndicator(),
                        )
                      else
                        Text(
                          'Payments are recorded manually for now — set this once you '
                          'have confirmation from the member.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// One labelled field. Renders [emptyText] in muted italics when [value]
/// is null, so a blank never looks like a rendering fault — several of
/// these columns are genuinely nullable.
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
    final theme = Theme.of(context);
    final isEmpty = value == null || value!.trim().isEmpty;
    final display = isEmpty ? (emptyText ?? '—') : value!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  display,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                    color: isEmpty ? theme.colorScheme.onSurfaceVariant : null,
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
