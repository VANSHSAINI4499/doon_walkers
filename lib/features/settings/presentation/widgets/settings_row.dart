import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// A titled group of settings rows on one card.
///
/// Rows share a card and are separated by hairlines rather than each
/// getting its own card — a settings screen of eight individual cards
/// reads as eight unrelated things, which is exactly the decoration the
/// calm direction cuts.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, this.title, required this.children});

  /// Optional group heading. Omit for a single ungrouped card.
  final String? title;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              title!.toUpperCase(),
              style: AppTextStyles.overline.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    // Indented past the icon column so the rule separates
                    // the text, not the whole row.
                    indent: AppSpacing.huge,
                    endIndent: AppSpacing.lg,
                    color: palette.border,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One settings row: icon, label, optional supporting line, and a trailing
/// slot (a chevron for navigation, a switch, a value).
///
/// [onTap] and [trailing] are independent — a row can navigate with a
/// chevron, host a switch that owns its own gesture, or show a read-only
/// value with no interaction at all.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.description,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;

  /// Second line explaining what the row does. Worth it for anything whose
  /// effect isn't obvious from its label (privacy toggles especially).
  final String? description;

  /// A current value shown at the end — "6,500 steps", "Dark".
  final String? value;

  /// Overrides the default trailing content (a chevron when [onTap] is
  /// set, nothing otherwise).
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Tints the icon and label with the danger colour — Sign Out only.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final ink = destructive ? palette.danger : palette.textPrimary;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          AppIcon(
            icon,
            size: 20,
            color: destructive ? palette.danger : palette.textSecondary,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.titleSmall.copyWith(color: ink),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: AppSpacing.md),
            Text(
              value!,
              style: AppTextStyles.labelMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: trailing!,
            )
          else if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: AppIcon(
                AppIcons.chevronRight,
                size: 18,
                color: palette.textDisabled,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: content,
      ),
    );
  }
}
