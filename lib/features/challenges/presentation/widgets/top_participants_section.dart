import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_top_participant.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/level_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top-N enrolled participants for a challenge — a Phase 21 deliverable
/// (`get_challenge_top_participants()`/[challengeTopParticipantsProvider])
/// that shipped with no consuming UI until Phase 23 wired it in here.
///
/// Public, like [ChallengeLeaderboardScreen] this preview sits above —
/// the RPC has no auth requirement, so this renders for guests too.
/// Reuses [LevelBadge] (the same widget Phase 22 audited onto Profile),
/// not a second one.
class TopParticipantsSection extends ConsumerWidget {
  const TopParticipantsSection({super.key, required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final topAsync = ref.watch(challengeTopParticipantsProvider(challenge.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppIcon(AppIcons.group, size: 18, color: palette.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Top Participants',
              style: AppTextStyles.titleMedium.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        topAsync.when(
          loading: () => const _TopParticipantsSkeleton(),
          error: (error, stack) {
            debugPrint('TopParticipantsSection: failed to load: $error');
            return Text(
              'Could not load participants right now.',
              style: AppTextStyles.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            );
          },
          data: (participants) {
            if (participants.isEmpty) {
              return AppCard(
                child: Text(
                  'No one has joined this challenge yet — be the first.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return Column(
              children: [
                for (final participant in participants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ParticipantRow(
                      participant: participant,
                      challenge: challenge,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant, required this.challenge});

  final ChallengeTopParticipant participant;
  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          _ParticipantAvatar(participant: participant, palette: palette),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        participant.displayName,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: palette.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    LevelBadge(level: participant.level, compact: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${participant.totalPoints} pts',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            challenge.metric.formatValue(participant.score),
            style: AppTextStyles.statSmall.copyWith(color: palette.primary),
          ),
        ],
      ),
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({required this.participant, required this.palette});

  final ChallengeTopParticipant participant;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final url = participant.avatarUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        width: 36,
        height: 36,
        child:
            (url == null || url.isEmpty)
                ? _Initials(name: participant.displayName, palette: palette)
                : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stack) => _Initials(
                        name: participant.displayName,
                        palette: palette,
                      ),
                ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.palette});

  final String name;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: palette.primarySubtle,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTextStyles.labelMedium.copyWith(color: palette.primary),
      ),
    );
  }
}

class _TopParticipantsSkeleton extends StatelessWidget {
  const _TopParticipantsSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: palette.border),
                ),
                child: const Row(
                  children: [
                    SkeletonCircle(size: 36),
                    SizedBox(width: AppSpacing.md),
                    Expanded(child: SkeletonBox(height: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
