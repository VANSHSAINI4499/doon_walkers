import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/notifications/domain/entities/notification_item.dart';
import 'package:flutter/material.dart';

/// One notification — title, body, and a formatted date. Read-only;
/// there's no per-user "read" state or per-item action in this phase.
class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.notification});

  final NotificationItem notification;

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = dt.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurEnabled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIcon(AppIcons.announce, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(notification.title, style: AppTextStyles.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(notification.body, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Text(
            _formatDate(notification.createdAt),
            style: AppTextStyles.secondary(AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}
