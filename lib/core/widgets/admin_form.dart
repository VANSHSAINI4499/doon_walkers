import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// Shared building blocks for the admin add/edit forms (Trek, Challenge,
/// Product — Redesign Phase 9), so the three forms read as one pattern
/// rather than three independently-designed screens: a section eyebrow,
/// a loading skeleton for the edit-mode prefill fetch, a full-screen
/// error state, and the Cancel/Save action row.

/// A small uppercase eyebrow that groups a run of fields inside a long
/// form — mirrors the overline treatment used elsewhere in the system
/// (Home stats, Profile sections) rather than inventing a new label style.
class AdminFormSectionLabel extends StatelessWidget {
  const AdminFormSectionLabel(this.label, {super.key, this.subtitle});

  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.overline.copyWith(color: AppColors.primary),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle!, style: AppTextStyles.secondary(AppTextStyles.bodySmall)),
        ],
      ],
    );
  }
}

/// Loading state for the edit-mode prefill fetch — a form-shaped
/// skeleton rather than a bare spinner, per the design system's "screens
/// load into skeletons" rule.
class AdminFormLoadingSkeleton extends StatelessWidget {
  const AdminFormLoadingSkeleton({super.key, this.showImage = false});

  final bool showImage;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showImage) ...[
                const SkeletonBox(height: 180, borderRadius: AppRadius.lg),
                const SizedBox(height: AppSpacing.xl),
              ],
              const SkeletonBox(height: 52, borderRadius: AppRadius.button),
              const SizedBox(height: AppSpacing.lg),
              const SkeletonBox(height: 100, borderRadius: AppRadius.button),
              const SizedBox(height: AppSpacing.lg),
              const SkeletonBox(height: 52, borderRadius: AppRadius.button),
              const SizedBox(height: AppSpacing.lg),
              const SkeletonBox(height: 52, borderRadius: AppRadius.button),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Full-screen "couldn't load this record" state for the edit-mode
/// prefill fetch failing outright.
class AdminFormErrorState extends StatelessWidget {
  const AdminFormErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIcons.error, size: 40, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            PremiumButton(label: 'Retry', variant: PremiumButtonVariant.glass, onPressed: onRetry),
          ],
        ),
      ),
    ),
  );
}

/// The Cancel/Save row every admin form ends on. Cancel is disabled
/// while saving so an in-flight write can't be abandoned mid-submit by
/// the same tap that started it.
class AdminFormActions extends StatelessWidget {
  const AdminFormActions({
    super.key,
    required this.isSaving,
    required this.saveLabel,
    required this.onSave,
    required this.onCancel,
  });

  final bool isSaving;
  final String saveLabel;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: PremiumButton(
          label: 'Cancel',
          variant: PremiumButtonVariant.glass,
          onPressed: isSaving ? null : onCancel,
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        flex: 2,
        child: PremiumButton(
          label: saveLabel,
          fullWidth: true,
          isLoading: isSaving,
          onPressed: onSave,
        ),
      ),
    ],
  );
}
