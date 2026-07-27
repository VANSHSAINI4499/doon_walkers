import 'package:doon_walkers/core/design_system.dart';
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
  ConsumerState<AdminBlocklistScreen> createState() =>
      _AdminBlocklistScreenState();
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

    final success = await ref
        .read(commentControllerProvider.notifier)
        .addBlocklistTerm(term);
    if (!mounted) return;

    if (success) {
      _controller.clear();
      _focusNode.requestFocus();
      return;
    }

    final palette = AppPalette.of(context);
    final error = ref.read(commentControllerProvider).error;
    debugPrint('AdminBlocklistScreen: failed to add "$term": $error');
    final message =
        error is DuplicateBlocklistTermException
            ? error.toString()
            : 'Could not add that term.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: palette.danger),
    );
  }

  Future<void> _remove(String term) async {
    final palette = AppPalette.of(context);
    final success = await ref
        .read(commentControllerProvider.notifier)
        .removeBlocklistTerm(term);
    if (!mounted || success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not remove "$term". Please try again.'),
        backgroundColor: palette.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final termsAsync = ref.watch(commentBlocklistProvider);
    final isSaving = ref.watch(commentControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Blocklist')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terms here are blocked case-insensitively as whole words or phrases.',
                      style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Add a term or phrase…',
                              isDense: true,
                            ),
                            onSubmitted: (_) => _add(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        PremiumButton(
                          label: 'Add',
                          icon: AppIcons.add,
                          isLoading: isSaving,
                          size: PremiumButtonSize.small,
                          onPressed: _add,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: termsAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) {
                    debugPrint(
                      'AdminBlocklistScreen: failed to load terms: $error',
                    );
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Could not load the blocklist.',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PremiumButton(
                            label: 'Retry',
                            icon: AppIcons.refresh,
                            variant: PremiumButtonVariant.glass,
                            size: PremiumButtonSize.small,
                            onPressed:
                                () => ref.invalidate(commentBlocklistProvider),
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
                          style: AppTextStyles.secondary(
                            AppTextStyles.bodyMedium,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: terms.length,
                      separatorBuilder:
                          (context, index) =>
                              const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final term = terms[index];
                        return AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  term,
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                              IconButton(
                                icon: AppIcon(
                                  AppIcons.close,
                                  size: 18,
                                  color: palette.textSecondary,
                                ),
                                tooltip: 'Remove',
                                onPressed:
                                    isSaving ? null : () => _remove(term),
                              ),
                            ],
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
