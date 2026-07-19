import 'package:doon_walkers/core/utils/link_launcher.dart';
import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';
import 'package:flutter/material.dart';

/// Tappable Instagram / WhatsApp / email / phone rows sourced from
/// [AppSettings]. All four `settings` values seeded in 0001 start out
/// empty (real values are entered later via the admin dashboard) — each
/// row only renders once its value is non-empty, so the section can't
/// show a dead link pointing nowhere.
class CommunityLinksSection extends StatelessWidget {
  const CommunityLinksSection({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final links = <_LinkRow>[
      if (settings.instagramUrl.isNotEmpty)
        _LinkRow(
          icon: Icons.camera_alt_outlined,
          label: 'Instagram',
          value: settings.instagramUrl,
          url: settings.instagramUrl,
        ),
      if (settings.whatsappUrl.isNotEmpty)
        _LinkRow(
          icon: Icons.chat_outlined,
          label: 'WhatsApp Group',
          value: 'Join the conversation',
          url: settings.whatsappUrl,
        ),
      if (settings.contactEmail.isNotEmpty)
        _LinkRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: settings.contactEmail,
          url: 'mailto:${settings.contactEmail}',
        ),
      if (settings.contactPhone.isNotEmpty)
        _LinkRow(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: settings.contactPhone,
          url: 'tel:${settings.contactPhone}',
        ),
    ];

    if (links.isEmpty) {
      return Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Contact details coming soon.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      child: Column(
        children: [
          for (var i = 0; i < links.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            ListTile(
              leading: Icon(links[i].icon, color: theme.colorScheme.primary),
              title: Text(links[i].label),
              subtitle: Text(links[i].value),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => openExternalLink(context, links[i].url),
            ),
          ],
        ],
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
