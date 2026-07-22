import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_status_chip.dart';
import 'package:flutter/material.dart';

/// One registration row — shared by [AdminRegistrationsScreen] (the
/// cross-trek roster) and the per-trek roster (Admin Dashboard → Trek
/// Registrations), rather than each screen keeping its own copy.
///
/// [showTrekTitle] defaults to true for the cross-trek roster, where the
/// trek name is the thing that tells rows apart. The per-trek roster
/// passes false — every row is already the same trek (its name is the
/// screen's AppBar title), so repeating it on every tile would be noise.
class RegistrationTile extends StatelessWidget {
  const RegistrationTile({
    super.key,
    required this.registration,
    required this.onTap,
    this.showTrekTitle = true,
  });

  final Registration registration;
  final VoidCallback onTap;
  final bool showTrekTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = registration;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      r.userName,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RegistrationStatusChip(status: r.paymentStatus),
                ],
              ),
              const SizedBox(height: 10),
              if (showTrekTitle) ...[
                _DetailRow(icon: Icons.terrain_rounded, text: r.trekTitle),
                const SizedBox(height: 6),
              ],
              _DetailRow(icon: Icons.email_outlined, text: r.userEmail),
              const SizedBox(height: 6),
              // Phone is nullable in the schema — say so plainly rather than
              // rendering an empty row that looks like a rendering bug.
              _DetailRow(
                icon: Icons.phone_outlined,
                text: r.userPhone ?? 'No phone on file',
                muted: r.userPhone == null,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _DetailRow(
                      icon: Icons.event_outlined,
                      text: 'Registered ${formatRegistrationDate(r.createdAt)}',
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text, this.muted = false});

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontStyle: muted ? FontStyle.italic : FontStyle.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
