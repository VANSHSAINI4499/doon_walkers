import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_form_sheet.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registration call-to-action on Trek Detail. Replaces the Phase 4
/// "Registration Opens Soon" placeholder.
///
/// Three states, driven by [myRegistrationForTrekProvider]:
///   - not registered (or guest) → "Register for this Trek"
///   - already registered → a status summary plus nothing to tap, since
///     cancelling lives on Profile where the user manages their own
///     registrations
///   - still loading → a disabled button, so a double-tap can't fire two
///     inserts and trip the UNIQUE constraint
///
/// A guest tapping Register is handed to [AuthGuard.requireAuth], which
/// bounces to sign-in and returns here afterwards — [returnPath] carries
/// a `register=1` flag so Trek Detail can reopen the form automatically
/// once they're back.
class TrekRegisterButton extends ConsumerWidget {
  const TrekRegisterButton({
    super.key,
    required this.trek,
  });

  /// The whole trek, not just id/title — the form sheet needs
  /// [Trek.requiresPayment]/[Trek.paymentQrCode] to decide whether to
  /// show payment UI at all.
  final Trek trek;

  Future<void> _openForm(BuildContext context) async {
    final registered = await showRegistrationFormSheet(context, trek: trek);
    if (registered == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You're registered — see you on the trail!")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (!trek.isPublished) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        child: const Text('Publish this trek to open registrations'),
      );
    }

    final registrationAsync = ref.watch(myRegistrationForTrekProvider(trek.id));

    return registrationAsync.when(
      // Disabled rather than hidden: keeps the layout stable and makes a
      // double-submit impossible while we're still resolving.
      loading: () => FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        child: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stack) {
        debugPrint('TrekRegisterButton: could not resolve registration state: $error');
        // Fail open when the trek is still upcoming — offering the
        // button is safe because the UNIQUE constraint (surfaced as
        // DuplicateRegistrationException) is the real duplicate guard,
        // not this lookup. A completed trek still shows the closed
        // state even here, since that doesn't depend on this lookup at
        // all — trek.isCompleted is known regardless of whether the
        // registration check succeeded.
        if (trek.isCompleted) return const _RegistrationClosed();
        return _RegisterCta(onPressed: () => _guardedOpen(context, ref));
      },
      data: (registration) {
        // An existing registration is shown regardless of isCompleted —
        // that's the member's own history, not a new registration
        // attempt, so it stays visible after the trek's date passes.
        if (registration != null) {
          return _AlreadyRegistered(registration: registration, theme: theme);
        }
        if (trek.isCompleted) return const _RegistrationClosed();
        return _RegisterCta(onPressed: () => _guardedOpen(context, ref));
      },
    );
  }

  void _guardedOpen(BuildContext context, WidgetRef ref) {
    AuthGuard.requireAuth(
      context,
      // Round-trips through sign-in and comes back here with the flag
      // Trek Detail uses to reopen this form automatically.
      returnPath: '${AppConstants.trekDetailLocation(trek.id)}?register=1',
      onAuthenticated: () => _openForm(context),
    );
  }
}

class _RegisterCta extends StatelessWidget {
  const _RegisterCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
      icon: const Icon(Icons.hiking_rounded),
      label: const Text('Register for this Trek'),
    );
  }
}

/// Shown instead of the Register CTA once a trek's date has passed and
/// the viewer never registered — registration is a business availability
/// rule keyed off [Trek.isCompleted], not something an admin toggles.
class _RegistrationClosed extends StatelessWidget {
  const _RegistrationClosed();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This trek has already taken place — registration is closed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlreadyRegistered extends StatelessWidget {
  const _AlreadyRegistered({required this.registration, required this.theme});

  final Registration registration;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // A free-trek registration shows no payment_status badge at all —
    // "nothing to verify" — per the Part C brief. involvedPayment is
    // derived from whether a screenshot was ever attached, not the
    // trek's current fee (which may have changed since).
    final subtitle = registration.involvedPayment
        ? 'Payment: ${registration.memberFacingStatusLabel} · Manage this from your Profile.'
        : 'Manage this from your Profile.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "You're registered",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
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
