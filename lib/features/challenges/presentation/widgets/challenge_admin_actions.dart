import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Inline admin action menu for a single challenge — edit / active-toggle /
/// delete — mirrors TrekAdminActions exactly. RLS
/// (`challenges_update_admin`/`challenges_delete_admin`) independently
/// rejects the underlying writes for anyone else, so a mis-rendered menu is
/// a cosmetic bug rather than a permission hole.
///
/// Redesign Phase 4 restyles the trigger, menu items, and delete dialog
/// onto the design system. The gating, the mutations, and the pending
/// state are unchanged.
class ChallengeAdminActions extends ConsumerStatefulWidget {
  const ChallengeAdminActions({super.key, required this.challenge, this.iconColor});

  final Challenge challenge;

  /// Overrides the menu glyph colour (a card renders it over content where
  /// the default may not read).
  final Color? iconColor;

  @override
  ConsumerState<ChallengeAdminActions> createState() => _ChallengeAdminActionsState();
}

class _ChallengeAdminActionsState extends ConsumerState<ChallengeAdminActions> {
  bool _isPending = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete challenge?'),
        content: Text(
          'This permanently deletes "${widget.challenge.title}", including its '
          'tier thresholds. This cannot be undone.',
        ),
        actions: [
          PremiumButton(
            label: 'Cancel',
            variant: PremiumButtonVariant.glass,
            size: PremiumButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          PremiumButton(
            label: 'Delete',
            icon: AppIcons.delete,
            variant: PremiumButtonVariant.danger,
            size: PremiumButtonSize.small,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isPending = true);
    final success = await ref
        .read(challengeAdminControllerProvider.notifier)
        .deleteChallenge(widget.challenge.id);
    if (!mounted) return;
    setState(() => _isPending = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete challenge. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _toggleActive() async {
    setState(() => _isPending = true);
    final success = await ref
        .read(challengeAdminControllerProvider.notifier)
        .setActive(widget.challenge.id, !widget.challenge.isActive);
    if (!mounted) return;
    setState(() => _isPending = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update challenge. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPending) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Admin actions',
      icon: AppIcon(AppIcons.more, color: widget.iconColor ?? AppColors.white),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            context.push(AppConstants.adminChallengeEditLocation(widget.challenge.id));
          case 'toggle':
            _toggleActive();
          case 'delete':
            _confirmDelete();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: _MenuRow(icon: AppIcons.edit, label: 'Edit'),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: _MenuRow(
            icon: widget.challenge.isActive ? AppIcons.hidden : AppIcons.visible,
            label: widget.challenge.isActive ? 'Deactivate' : 'Activate',
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: _MenuRow(icon: AppIcons.delete, label: 'Delete', color: AppColors.danger),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textPrimary;
    return Row(
      children: [
        AppIcon(icon, size: 20, color: tint),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppTextStyles.tinted(AppTextStyles.bodyMedium, tint)),
      ],
    );
  }
}
