import 'package:doon_walkers/features/comments/domain/entities/comment.dart';
import 'package:doon_walkers/features/comments/presentation/providers/comment_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Admin-facing CRUD on `public.comment_blocklist` — the real answer to
/// "how does an admin add a term without touching code or the Supabase
/// dashboard directly." List-based content filtering has an inherent
/// ceiling no matter how large the list gets (see the limits documented
/// on [commentMatchesBlocklist]) — what actually needs to scale over
/// time is how easy it is to keep adding to it, not the size of any one
/// seed. This screen is that mechanism.
///
/// Reachable from [CommentModerationScreen]'s app bar action, not its
/// own Admin Dashboard card — it's a secondary tool of comment
/// moderation, not a first-class destination on its own.
class AdminBlocklistScreen extends ConsumerStatefulWidget {
  const AdminBlocklistScreen({super.key});

  @override
  ConsumerState<AdminBlocklistScreen> createState() => _AdminBlocklistScreenState();
}

class _AdminBlocklistScreenState extends ConsumerState<AdminBlocklistScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final term = _controller.text.trim();
    if (term.isEmpty) return;

    final success =
        await ref.read(commentControllerProvider.notifier).addBlocklistTerm(term);
    if (!mounted) return;

    if (success) {
      _controller.clear();
      _focusNode.requestFocus();
      return;
    }

    final error = ref.read(commentControllerProvider).error;
    debugPrint('AdminBlocklistScreen: failed to add "$term": $error');
    final message =
        error is DuplicateBlocklistTermException ? error.toString() : 'Could not add that term.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  Future<void> _remove(String term) async {
    final success = await ref.read(commentControllerProvider.notifier).removeBlocklistTerm(term);
    if (!mounted || success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not remove "$term". Please try again.'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final termsAsync = ref.watch(commentBlocklistProvider);
    final isSaving = ref.watch(commentControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Blocklist')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Terms here are blocked case-insensitively, as whole '
                'words or phrases — adding "trek" would not also block '
                '"trekking". Enforced server-side on every comment; this '
                'list is one layer, not a complete filter — admin '
                'moderation (hide/show) is still the real backstop.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Add a term or phrase…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: isSaving ? null : _add,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: termsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) {
                    debugPrint('AdminBlocklistScreen: failed to load terms: $error');
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Could not load the blocklist.',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => ref.invalidate(commentBlocklistProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },
                  data: (terms) {
                    if (terms.isEmpty) {
                      return Center(
                        child: Text(
                          'No terms yet.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: terms.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final term = terms[index];
                        return ListTile(
                          dense: true,
                          title: Text(term),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Remove',
                            onPressed: isSaving ? null : () => _remove(term),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
