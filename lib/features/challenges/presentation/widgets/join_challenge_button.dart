import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Join / Leave / Ended button for a challenge detail screen.
///
/// Phase 21. Reads [challengeEnrollmentStatusProvider] and delegates
/// mutations to [enrollmentControllerProvider]. Shows a confirmation
/// dialog before un-enrolling to prevent accidental taps.
///
/// The three states:
/// - **Not enrolled** → green "Join Challenge" filled button
/// - **Enrolled** → outlined "Leave Challenge" danger button
/// - **Challenge ended** → disabled grey "Challenge Ended" button
///   (end_date < today for a customRange challenge)
class JoinChallengeButton extends ConsumerWidget {
  const JoinChallengeButton({super.key, required this.challenge});

  final Challenge challenge;

  bool get _hasEnded {
    if (challenge.endDate == null) return false;
    final today = DateTime.now();
    final endDay = DateTime(
      challenge.endDate!.year,
      challenge.endDate!.month,
      challenge.endDate!.day,
    );
    final todayDay = DateTime(today.year, today.month, today.day);
    return endDay.isBefore(todayDay);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_hasEnded) {
      return _EndedButton();
    }

    final enrolledAsync = ref.watch(challengeEnrollmentStatusProvider(challenge.id));
    final controller = ref.watch(enrollmentControllerProvider.notifier);
    final isLoading = ref.watch(enrollmentControllerProvider).isLoading;

    return enrolledAsync.when(
      loading: () => _LoadingButton(),
      error: (_, __) => _LoadingButton(),
      data: (isEnrolled) {
        if (isEnrolled) {
          return _LeaveButton(
            isLoading: isLoading,
            onPressed: () => _confirmLeave(context, ref, controller),
          );
        }
        return _JoinButton(
          isLoading: isLoading,
          onPressed: () async {
            final ok = await controller.enroll(challenge.id);
            if (ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Joined "${challenge.title}" — +10 pts bonus!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    EnrollmentController controller,
  ) async {
    final palette = AppPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave challenge?'),
        content: const Text(
          'Your progress and earned points are kept. '
          'You can re-join at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: palette.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.unenroll(challenge.id);
    }
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Join Challenge',
      icon: AppIcons.add,
      variant: AppButtonVariant.primary,
      isLoading: isLoading,
      onPressed: isLoading ? null : onPressed,
    );
  }
}

class _LeaveButton extends StatelessWidget {
  const _LeaveButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.danger,
        side: BorderSide(color: palette.danger.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.danger,
              ),
            )
          : AppIcon(AppIcons.close, size: 16, color: palette.danger),
      label: Text('Leave Challenge',
          style: AppTextStyles.labelLarge.copyWith(color: palette.danger)),
      onPressed: isLoading ? null : onPressed,
    );
  }
}

class _EndedButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textDisabled,
        side: BorderSide(color: palette.border),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
      icon: AppIcon(AppIcons.calendar, size: 16, color: palette.textDisabled),
      label: Text(
        'Challenge Ended',
        style: AppTextStyles.labelLarge.copyWith(color: palette.textDisabled),
      ),
      onPressed: null,
    );
  }
}

class _LoadingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Loading…',
      variant: AppButtonVariant.primary,
      isLoading: true,
      onPressed: null,
    );
  }
}
