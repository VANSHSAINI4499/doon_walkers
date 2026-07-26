import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/utils/link_launcher.dart';
import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';
import 'package:flutter/material.dart';

/// Which contact channels to render.
enum CommunityLinkFilter {
  /// Every channel that has a value — Instagram, WhatsApp, email, phone.
  all,

  /// Only the channels that actually reach a person who can help:
  /// WhatsApp, email, phone. Instagram is a broadcast feed, not a
  /// support channel, so it is excluded rather than inviting someone
  /// with a problem to DM a photo grid.
  supportOnly,
}

/// Tappable Instagram / WhatsApp / email / phone rows sourced from
/// [AppSettings].
///
/// Unchanged behaviour: all four `settings` values start empty (real
/// values are entered later via the admin dashboard), and each row only
/// renders once its value is non-empty, so the section can't show a dead
/// link pointing nowhere; when none are set it shows a soft empty state.
///
/// Moved here from `features/home` in Redesign 2.0 Phase 10 and made
/// theme-aware. The per-row accent colours are gone — four link rows in
/// four different hues is decoration, not information. Icons take the
/// single accent; the row itself carries the meaning.
class CommunityLinksSection extends StatelessWidget {
  const CommunityLinksSection({
    super.key,
    required this.settings,
    this.filter = CommunityLinkFilter.all,
    this.emptyMessage = 'Contact details coming soon.',
  });

  final AppSettings settings;
  final CommunityLinkFilter filter;

  /// Shown when no channel has a value yet.
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final supportOnly = filter == CommunityLinkFilter.supportOnly;

    final links = <_LinkRow>[
      if (!supportOnly && settings.instagramUrl.isNotEmpty)
        _LinkRow(
          icon: AppIcons.camera,
          label: 'Instagram',
          value: settings.instagramUrl,
          url: settings.instagramUrl,
        ),
      if (settings.whatsappUrl.isNotEmpty)
        _LinkRow(
          icon: AppIcons.comment,
          label: 'WhatsApp Group',
          value: 'Join the conversation',
          url: settings.whatsappUrl,
        ),
      if (settings.contactEmail.isNotEmpty)
        _LinkRow(
          icon: AppIcons.email,
          label: 'Email',
          value: settings.contactEmail,
          url: 'mailto:${settings.contactEmail}',
        ),
      if (settings.contactPhone.isNotEmpty)
        _LinkRow(
          icon: AppIcons.phone,
          label: 'Phone',
          value: settings.contactPhone,
          url: 'tel:${settings.contactPhone}',
        ),
    ];

    if (links.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            AppIcon(AppIcons.connect, size: 22, color: palette.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                emptyMessage,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          for (var i = 0; i < links.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: AppSpacing.huge,
                color: palette.border,
              ),
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
    final palette = AppPalette.of(context);

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
                color: palette.primarySubtle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: AppIcon(link.icon, size: 20, color: palette.primary),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    link.label,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    link.value,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: palette.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppIcon(
              AppIcons.openExternal,
              size: 18,
              color: palette.textSecondary,
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
  });

  final IconData icon;
  final String label;
  final String value;
  final String url;
}
