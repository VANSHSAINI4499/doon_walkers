import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/home/presentation/widgets/home_section_header.dart';
import 'package:flutter/material.dart';

/// A titled prose block (Our Story, Vision, Mission, ...) sourced from a
/// `public.settings` value.
///
/// Unchanged behaviour: renders nothing if [body] is empty — a row
/// deleted or blanked out via the Supabase dashboard quietly disappears
/// rather than showing an empty card. Restyled onto a glass card with the
/// Home section header.
class AboutTextSection extends StatelessWidget {
  const AboutTextSection({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    this.accent = AppColors.primary,
  });

  final String title;
  final IconData icon;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (body.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeSectionHeader(title: title, icon: icon, accent: accent),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            blurEnabled: false,
            child: Text(
              body,
              style: AppTextStyles.secondary(AppTextStyles.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}
