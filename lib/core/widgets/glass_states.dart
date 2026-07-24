import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// A glass empty-state card — an icon, a message, and an optional action —
/// for "no items yet" sections (Profile's registrations / wishlist /
/// inquiries, and anywhere else a list can be empty). Replaces the old
/// plain-text/plain-container empty states with the design-system look.
class GlassEmptyState extends StatelessWidget {
  const GlassEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurEnabled: false,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          AppIcon(icon, size: 32, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            PremiumButton(
              label: actionLabel!,
              variant: PremiumButtonVariant.glass,
              size: PremiumButtonSize.small,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact inline "couldn't load … · Retry" row for a section that
/// failed to load, in the design system's danger tint.
class GlassSectionError extends StatelessWidget {
  const GlassSectionError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(message, style: AppTextStyles.tinted(AppTextStyles.bodySmall, AppColors.danger)),
        ),
        PremiumButton(
          label: 'Retry',
          variant: PremiumButtonVariant.ghost,
          size: PremiumButtonSize.small,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
