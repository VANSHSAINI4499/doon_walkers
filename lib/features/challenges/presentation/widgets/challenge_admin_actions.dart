import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Inline admin action menu for a single challenge — edit /
/// active-toggle / delete — mirrors ProductAdminActions/
/// TrekAdminActions exactly. RLS (`challenges_update_admin`/
/// `challenges_delete_admin`) independently rejects the underlying
/// writes for anyone else, so a mis-rendered menu is a cosmetic bug
/// rather than a permission hole.
class ChallengeAdminActions extends ConsumerStatefulWidget {
  const ChallengeAdminActions({super.key, required this.challenge});

  final Challenge challenge;

  @override
  ConsumerState<ChallengeAdminActions> createState() => _ChallengeAdminActionsState();
}

class _ChallengeAdminActionsState extends ConsumerState<ChallengeAdminActions> {
  bool _isPending = false;

  Future<void> _confirmDelete() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete challenge?'),
        content: Text(
          'This permanently deletes "${widget.challenge.title}", including its '
          'tier thresholds. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
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
        SnackBar(
          content: const Text('Could not delete challenge. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
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
        SnackBar(
          content: const Text('Could not update challenge. Please try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isPending) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Admin actions',
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
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: ListTile(
            leading: Icon(
              widget.challenge.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            ),
            title: Text(widget.challenge.isActive ? 'Deactivate' : 'Activate'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
            title: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
