import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';
import 'package:doon_walkers/features/notifications/domain/services/notification_grouping.dart';
import 'package:flutter/material.dart';

/// One notification row — icon chip, title, body, relative timestamp, and
/// an unread dot.
///
/// ## Icons are derived, not invented
///
/// The reference showed typed notifications (Step Goal Achieved, Trek
/// Reminder, Badge Earned, Someone Liked Your Post). None of those exist:
/// `public.notifications` has no `type` column and nothing generates them.
/// The **one** real distinction is [NotificationItem.isTargeted] —
/// broadcast to the community, or addressed to one member — so that is the
/// only thing the icon varies on:
///
///  - broadcast → a megaphone in the neutral ink
///  - targeted  → a mail glyph in the accent, because a message addressed
///    to you personally is the one that warrants standing out
///
/// Read state is per-device (see `NotificationReadTracker`), so the unread
/// dot means "this device hasn't shown you this yet", not an account-level
/// fact.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.isUnread,
    this.onTap,
    this.now,
  });

  final NotificationItem notification;
  final bool isUnread;
  final VoidCallback? onTap;

  /// Injectable for tests; defaults to the wall clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final targeted = notification.isTargeted;
    final accent = targeted ? palette.accent : palette.textSecondary;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      // An unread row is marked by a tinted hairline rather than a
      // different fill: a filled-vs-flat list reads as two kinds of card,
      // which is louder than "one of these is new".
      borderColor: isUnread ? palette.primary.withValues(alpha: 0.45) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: targeted ? palette.accentContainer : palette.cardHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: AppIcon(
              targeted ? AppIcons.email : AppIcons.announce,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      formatNotificationTime(notification.createdAt, now: now),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    if (isUnread) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: palette.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                if (notification.body.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    notification.body.trim(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
