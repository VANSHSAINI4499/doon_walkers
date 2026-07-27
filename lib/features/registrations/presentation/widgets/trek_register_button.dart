import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/domain/trek_checkin_window.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_form_sheet.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Registration call-to-action on Trek Detail.
///
/// Three states, driven by [myRegistrationForTrekProvider]:
///   - not registered (or guest) → "Register for this Trek"
///   - already registered → a status summary plus nothing to tap, since
///     cancelling lives on Profile where the user manages their own
///     registrations
///   - still loading → a disabled button, so a double-tap can't fire two
///     inserts and trip the UNIQUE constraint
///
/// A guest (or a signed-in but phone-unverified user) tapping Register is
/// handed to [AuthGuard.requirePhoneVerified], which bounces to sign-in
/// and/or phone verification and returns here afterwards — [returnPath]
/// carries a `register=1` flag so Trek Detail can reopen the form
/// automatically once they're back.
///
/// Redesign 2.0 Phase 15 restyles the button and status cards calm (flat
/// cards, no glow). Every state and every gating condition below — the
/// unpublished guard, the loading double-submit guard, the
/// fail-open-when-upcoming error branch, the completed→closed rule, and
/// the already-registered summary — is exactly as it was; only the
/// widgets drawing them changed.
class TrekRegisterButton extends ConsumerWidget {
  const TrekRegisterButton({
    super.key,
    required this.trek,
  });

  /// The whole trek, not just id/title — the form sheet needs
  /// [Trek.requiresPayment]/[Trek.paymentQrCode] to decide whether to show
  /// payment UI at all.
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
    if (!trek.isPublished) {
      return const AppButton(
        label: 'Publish this trek to open registrations',
        onPressed: null,
        fullWidth: true,
      );
    }

    final registrationAsync = ref.watch(myRegistrationForTrekProvider(trek.id));

    return registrationAsync.when(
      // Disabled rather than hidden: keeps the layout stable and makes a
      // double-submit impossible while we're still resolving.
      loading: () => const AppButton(
        label: 'Register for this Trek',
        icon: AppIcons.hiking,
        isLoading: true,
        fullWidth: true,
        onPressed: null,
      ),
      error: (error, stack) {
        debugPrint('TrekRegisterButton: could not resolve registration state: $error');
        // Fail open when the trek is still upcoming — offering the button
        // is safe because the UNIQUE constraint (surfaced as
        // DuplicateRegistrationException) is the real duplicate guard, not
        // this lookup. A completed trek still shows the closed state even
        // here, since that doesn't depend on this lookup at all —
        // trek.isCompleted is known regardless of whether the check
        // succeeded.
        if (trek.isCompleted) return const _RegistrationClosed();
        return _RegisterCta(onPressed: () => _guardedOpen(context, ref));
      },
      data: (registration) {
        // An existing registration is shown regardless of isCompleted —
        // that's the member's own history, not a new registration attempt,
        // so it stays visible after the trek's date passes.
        if (registration != null) {
          return _AlreadyRegistered(registration: registration, trek: trek);
        }
        if (trek.isCompleted) return const _RegistrationClosed();

        final spotsLeft = ref.watch(trekSpotsLeftProvider(trek.id)).valueOrNull;
        if (spotsLeft == 0) {
          return const AppButton(
            label: 'Trek Full',
            icon: AppIcons.hiking,
            fullWidth: true,
            onPressed: null,
          );
        }
        return _RegisterCta(onPressed: () => _guardedOpen(context, ref));
      },
    );
  }

  void _guardedOpen(BuildContext context, WidgetRef ref) {
    AuthGuard.requirePhoneVerified(
      context,
      // Round-trips through sign-in (and, if needed, phone verification)
      // and comes back here with the flag Trek Detail uses to reopen
      // this form automatically.
      returnPath: '${AppConstants.trekDetailLocation(trek.id)}?register=1',
      onVerified: () => _openForm(context),
    );
  }
}

class _RegisterCta extends StatelessWidget {
  const _RegisterCta({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Register for this Trek',
      icon: AppIcons.hiking,
      size: AppButtonSize.large,
      fullWidth: true,
      onPressed: onPressed,
    );
  }
}

/// Shown instead of the Register CTA once a trek's date has passed and the
/// viewer never registered — registration is a business availability rule
/// keyed off [Trek.isCompleted], not something an admin toggles.
class _RegistrationClosed extends StatelessWidget {
  const _RegistrationClosed();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          AppIcon(AppIcons.eventBusy, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'This trek has already taken place — registration is closed.',
              style: AppTextStyles.bodyMedium.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlreadyRegistered extends StatelessWidget {
  const _AlreadyRegistered({required this.registration, required this.trek});

  final Registration registration;

  /// Needed for the Phase QR-2 "Check In" entry point below — its
  /// window visibility depends on [Trek.trekDate]/[Trek.trekStartTime],
  /// and the scanner screen needs [Trek.id] to navigate to.
  final Trek trek;

  @override
  Widget build(BuildContext context) {
    // A free-trek registration shows no payment_status detail at all —
    // "nothing to verify" — per the Part C brief. involvedPayment is
    // derived from whether a screenshot was ever attached, not the trek's
    // current fee (which may have changed since).
    final subtitle = registration.involvedPayment
        ? 'Payment: ${registration.memberFacingStatusLabel} · Manage this from your Profile.'
        : 'Manage this from your Profile.';

    // Phase QR-2 — only offered once already checked in isn't the case,
    // and only near/within the active check-in window, so the button
    // isn't sitting there confusingly at a random unrelated time.
    final showCheckIn = registration.checkedInAt == null &&
        shouldShowCheckinEntryPoint(
          trekDate: trek.trekDate,
          trekStartTime: trek.trekStartTime,
          now: DateTime.now(),
        );

    final palette = AppPalette.of(context);
    final checkedIn = registration.checkedInAt != null;

    return AppCard(
      // A tinted hairline marks this as a live, positive state — the
      // calm replacement for the glow this card used to cast.
      borderColor: palette.primary.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIcon(
                checkedIn ? AppIcons.verified : AppIcons.checkCircle,
                color: palette.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      checkedIn ? "You're checked in" : "You're registered",
                      style: AppTextStyles.titleSmall.copyWith(color: palette.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showCheckIn) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Check In',
              icon: AppIcons.qr,
              variant: AppButtonVariant.glass,
              fullWidth: true,
              onPressed: () => context.push(AppConstants.trekCheckInLocation(trek.id)),
            ),
          ],
        ],
      ),
    );
  }
}
