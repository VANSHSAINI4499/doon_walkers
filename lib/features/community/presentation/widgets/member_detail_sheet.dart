import 'package:cached_network_image/cached_network_image.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:flutter/material.dart';

void showMemberDetailSheet({
  required BuildContext context,
  required String displayName,
  required String? avatarUrl,
  required int level,
  required int totalPoints,
  DateTime? createdAt,
}) {
  final palette = AppPalette.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (context) {
      final joinedStr = createdAt != null
          ? 'Member since ${createdAt.month}/${createdAt.year}'
          : null;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.primarySubtle,
                  border: Border.all(color: palette.border, width: 2),
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _Initials(displayName),
                        )
                      : _Initials(displayName),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: palette.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  LevelBadge(level: level),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$totalPoints Community Points',
                style: AppTextStyles.titleSmall.copyWith(
                  color: palette.primary,
                ),
              ),
              if (joinedStr != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  joinedStr,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      );
    },
  );
}

class _Initials extends StatelessWidget {
  const _Initials(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTextStyles.headlineSmall.copyWith(
          color: palette.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
