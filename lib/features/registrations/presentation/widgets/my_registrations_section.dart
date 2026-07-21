import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "My Registrations" on Profile — the signed-in user's own registered
/// treks, with self-service cancellation.
///
/// Scoped by [myRegistrationsProvider], which filters to the current
/// user *and* is backed by `registrations_select` (own row or admin), so
/// another member's sensitive detail can't appear here even if the
/// client-side filter were wrong.
///
/// Cancelling DELETEs the row rather than setting `payment_status` to
/// `cancelled`: that column is admin-only, enforced by the
/// `prevent_payment_status_self_edit` trigger, and this phase
/// deliberately doesn't work around that guard.
class MyRegistrationsSection extends ConsumerWidget {
  const MyRegistrationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final registrationsAsync = ref.watch(myRegistrationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.event_available_outlined, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'My Registrations',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        registrationsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) {
            debugPrint('MyRegistrationsSection: failed to load registrations: $error');
            return Row(
              children: [
                Expanded(
                  child: Text(
                    'Could not load your registrations.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(myRegistrationsProvider),
                  child: const Text('Retry'),
                ),
              ],
            );
          },
          data: (registrations) {
            if (registrations.isEmpty) return const _EmptyMyRegistrations();
            return Column(
              children: [
                for (final registration in registrations) ...[
                  _MyRegistrationTile(registration: registration),
                  const SizedBox(height: 12),
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.hiking_rounded, size: 32, color: theme.colorScheme.outline),
          const SizedBox(height: 10),
          Text(
            "You haven't registered for any treks yet.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => context.go(AppConstants.routeTrekLibrary),
            child: const Text('Browse Treks'),
          ),
        ],
      ),
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
    final theme = Theme.of(context);
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
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel registration'),
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
          success
              ? 'Registration cancelled.'
              : 'Could not cancel your registration. Please try again.',
        ),
        backgroundColor: success ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.registration;

    return Card(
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
                    r.trekTitle,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // A free-trek registration shows no payment_status badge
                // at all — "nothing to verify" — per the Part C brief.
                if (r.involvedPayment) ...[
                  const SizedBox(width: 8),
                  RegistrationStatusChip(status: r.paymentStatus, label: r.memberFacingStatusLabel),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Registered ${formatRegistrationDate(r.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _isPending
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: _confirmCancel,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Cancel registration'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
