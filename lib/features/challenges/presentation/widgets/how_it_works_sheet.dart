import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// Static, plain-English explanation of the points/challenge system —
/// Phase 24. Opened from Explore's bottom "How it works" link.
///
/// Every figure here is real and already awarded elsewhere in the app
/// (see `award_points()`/`enroll_in_challenge()`/`ActivityRepositoryImpl`/
/// `RegistrationRepositoryImpl`) — this sheet is a summary, not a new
/// source of truth, so if any of these numbers ever change they need to
/// change here too.
Future<void> showHowItWorksSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _HowItWorksSheet(),
  );
}

class _HowItWorksSheet extends StatelessWidget {
  const _HowItWorksSheet();

  static const _points = [
    ('Join a challenge', '+10 pts, once per challenge'),
    ('Hit your daily step goal', '+25 pts, once per day'),
    ('Check in to a trek', '+100 pts'),
    (
      'Complete a challenge (reach Platinum)',
      "+ that challenge's own point value",
    ),
    (
      'Levels',
      'Your total points decide your level — shown as the badge next to your name',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'How points work',
              style: AppTextStyles.headlineSmall.copyWith(
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final (title, detail) in _points)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            detail,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Got it',
              variant: AppButtonVariant.glass,
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
