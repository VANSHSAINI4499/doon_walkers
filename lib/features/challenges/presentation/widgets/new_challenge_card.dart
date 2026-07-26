import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/challenge_icon.dart';
import 'package:flutter/material.dart';

/// A compact grid tile for Explore's "New Challenges" section — Phase 24.
///
/// Deliberately smaller than [ChallengeCard]: a 2-column grid cell has
/// far less room than a full-width list row, so this drops the
/// description, meta chips, and progress bar and keeps only icon, title,
/// point value, and the "NEW" tag. Every card in this section already IS
/// one of the newest (the section itself is `challenges.take(4)` off
/// `created_at DESC`), so the tag needs no separate freshness cutoff.
class NewChallengeCard extends StatelessWidget {
  const NewChallengeCard({super.key, required this.challenge, required this.onTap});

  final Challenge challenge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: palette.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  ChallengeIcon.forKey(challenge.icon),
                  size: 16,
                  color: palette.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.accentContainer,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'NEW',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            challenge.title,
            style: AppTextStyles.titleSmall.copyWith(color: palette.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '+${challenge.pointValue} pts',
            style: AppTextStyles.labelSmall.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
