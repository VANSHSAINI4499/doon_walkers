import 'package:doon_walkers/core/widgets/section_header.dart';
import 'package:flutter/material.dart';

/// A titled prose block (Our Story, Vision, Mission, ...) sourced from a
/// `public.settings` value.
///
/// Renders nothing if [body] is empty — a row deleted or blanked out via
/// the Supabase dashboard should quietly disappear from the page rather
/// than show an empty card.
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

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: title, icon: icon),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
