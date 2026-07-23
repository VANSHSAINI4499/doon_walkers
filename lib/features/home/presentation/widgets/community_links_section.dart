import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/utils/link_launcher.dart';
import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';
import 'package:flutter/material.dart';

/// Tappable Instagram / WhatsApp / email / phone rows sourced from
/// [AppSettings].
///
/// Unchanged behaviour: all four `settings` values start empty (real
/// values are entered later via the admin dashboard), and each row only
/// renders once its value is non-empty, so the section can't show a dead
/// link pointing nowhere; when none are set it shows a soft "coming soon"
/// card. Restyled onto glass with the design system's press feedback.
class CommunityLinksSection extends StatelessWidget {
  const CommunityLinksSection({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final links = <_LinkRow>[
      if (settings.instagramUrl.isNotEmpty)
        _LinkRow(
          icon: AppIcons.camera,
          label: 'Instagram',
          value: settings.instagramUrl,
          url: settings.instagramUrl,
          accent: AppColors.accent,
        ),
      if (settings.whatsappUrl.isNotEmpty)
        _LinkRow(
          icon: AppIcons.comment,
          label: 'WhatsApp Group',
          value: 'Join the conversation',
          url: settings.whatsappUrl,
          accent: AppColors.primary,
        ),
      if (settings.contactEmail.isNotEmpty)
        _LinkRow(
          icon: AppIcons.email,
          label: 'Email',
          value: settings.contactEmail,
          url: 'mailto:${settings.contactEmail}',
          accent: AppColors.secondary,
        ),
      if (settings.contactPhone.isNotEmpty)
        _LinkRow(
          icon: AppIcons.phone,
          label: 'Phone',
          value: settings.contactPhone,
          url: 'tel:${settings.contactPhone}',
          accent: AppColors.gold,
        ),
    ];

    if (links.isEmpty) {
      return GlassCard(
        blurEnabled: false,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Row(
          children: [
            const AppIcon(
              AppIcons.connect,
              size: 22,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Contact details coming soon.',
                style: AppTextStyles.secondary(AppTextStyles.bodyMedium),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      blurEnabled: false,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          for (var i = 0; i < links.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: AppSpacing.huge),
            _CommunityLinkTile(link: links[i]),
          ],
        ],
      ),
    );
  }
}

class _CommunityLinkTile extends StatelessWidget {
  const _CommunityLinkTile({required this.link});

  final _LinkRow link;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => openExternalLink(context, link.url),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: link.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: AppIcon(link.icon, size: 20, color: link.accent),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(link.label, style: AppTextStyles.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    link.value,
                    style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const AppIcon(
              AppIcons.openExternal,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.url,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final String url;
  final Color accent;
}
