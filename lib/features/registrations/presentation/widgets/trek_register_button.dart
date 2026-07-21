import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_form_sheet.dart';
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
    required this.trekId,
    required this.trekTitle,
    required this.isPublished,
  });

  final String trekId;
  final String trekTitle;

  /// A draft trek is admin-only and not open for registration yet.
  final bool isPublished;

  Future<void> _openForm(BuildContext context) async {
    final registered = await showRegistrationFormSheet(
      context,
      trekId: trekId,
      trekTitle: trekTitle,
    );
    if (registered == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You're registered — see you on the trail!")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (!isPublished) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        child: const Text('Publish this trek to open registrations'),
      );
    }

    final registrationAsync = ref.watch(myRegistrationForTrekProvider(trekId));

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
        // Fail open — offering the button is safe because the UNIQUE
        // constraint (surfaced as DuplicateRegistrationException) is the
        // real duplicate guard, not this lookup.
        return _RegisterCta(onPressed: () => _guardedOpen(context, ref));
      },
      data: (registration) {
        if (registration == null) {
          return _RegisterCta(onPressed: () => _guardedOpen(context, ref));
        }
        return _AlreadyRegistered(registration: registration, theme: theme);
      },
    );
  }

  void _guardedOpen(BuildContext context, WidgetRef ref) {
    AuthGuard.requireAuth(
      context,
      // Round-trips through sign-in and comes back here with the flag
      // Trek Detail uses to reopen this form automatically.
      returnPath: '${AppConstants.trekDetailLocation(trekId)}?register=1',
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

class _AlreadyRegistered extends StatelessWidget {
  const _AlreadyRegistered({required this.registration, required this.theme});

  final Registration registration;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
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
                  'Payment: ${registration.paymentStatus.label} · '
                  'Manage this from your Profile.',
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
