import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// A titled prose block (Our Story, Vision, Mission, ...) sourced from a
/// `public.settings` value.
///
/// Unchanged behaviour: renders nothing if [body] is empty — a row
/// deleted or blanked out via the Supabase dashboard quietly disappears
/// rather than showing an empty card.
///
/// Moved here from `features/home` in Redesign 2.0 Phase 10, when About
/// stopped being a section of Home and became its own drawer
/// destination. Restyled onto the calm card and made theme-aware.
///
/// The per-block [accent] the old version took is gone: six prose blocks
/// each in a different hue was the decorative habit the calm direction
/// rules out. One accent, used for the icon only.
class AboutTextSection extends StatelessWidget {
  const AboutTextSection({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
  });

  final String title;
  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (body.trim().isEmpty) return const SizedBox.shrink();

    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIcon(icon, size: 18, color: palette.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Text(
              body,
              style: AppTextStyles.bodyLarge.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
