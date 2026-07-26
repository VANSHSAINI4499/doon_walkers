/// Shared building blocks for a full "View All" list screen — the
/// dedicated destinations [WishlistScreen]/[MyEnquiriesScreen]/
/// [MyRegistrationsScreen] open from Profile's dashboard previews.
///
/// Deliberately distinct from [GlassSectionError]/[GlassEmptyState]
/// (the compact, inline forms those Profile previews use): a full
/// screen with nothing else on it reads better with a larger, centered
/// state, matching the loading/error/empty convention this app already
/// uses on its other standalone list screens (Notifications, Comment
/// Moderation, the admin rosters).
library;

import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// Client-side substring filter field — not a server round trip per
/// keystroke, same pattern `merchandise_catalog_screen.dart` already
/// established.
class ListSearchField extends StatelessWidget {
  const ListSearchField({super.key, required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: AppIcon(AppIcons.search, size: 20, color: palette.textSecondary),
        filled: true,
        fillColor: palette.cardHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class ListScreenSkeleton extends StatelessWidget {
  const ListScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // SkeletonList is a plain (non-scrolling) Column sized to its
    // content — this screen places it inside a bounded Expanded
    // region, not an already-unbounded scroll view the way Profile's
    // dashboard previews do, so it needs its own scroll container or
    // enough cards overflow the viewport on a typical phone height.
    return const SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: SkeletonList(count: 5, padding: EdgeInsets.zero),
    );
  }
}

class ListScreenError extends StatelessWidget {
  const ListScreenError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(AppIcons.error, size: 44, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            PremiumButton(
              label: 'Retry',
              icon: AppIcons.refresh,
              variant: PremiumButtonVariant.glass,
              size: PremiumButtonSize.small,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class ListScreenEmpty extends StatelessWidget {
  const ListScreenEmpty({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 44, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
