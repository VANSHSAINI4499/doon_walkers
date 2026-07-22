import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/comments/domain/comment_blocklist_matcher.dart';
import 'package:doon_walkers/features/comments/domain/entities/comment.dart';
import 'package:doon_walkers/features/comments/presentation/providers/comment_providers.dart';
import 'package:doon_walkers/features/comments/presentation/widgets/comment_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Trek Detail's comment section — input box plus the thread below it.
///
/// A guest sees a tappable "Sign in to comment" placeholder instead of
/// a real input; tapping it goes through [AuthGuard.requireAuth],
/// which bounces to sign-in and returns here with `?comment=1` — see
/// [autoFocusInput], set from that flag by [TrekDetailScreen].
class CommentThread extends ConsumerStatefulWidget {
  const CommentThread({
    super.key,
    required this.trekId,
    this.autoFocusInput = false,
  });

  final String trekId;

  /// Set from the `?comment=1` query flag [TrekDetailScreen] reads off
  /// the sign-in return path. Unlike TrekRegisterButton's auto-reopened
  /// modal sheet, focusing an already-focused node is a harmless no-op,
  /// so this doesn't need a "handled" guard against re-firing on
  /// rebuild — it only ever runs once, in [initState].
  final bool autoFocusInput;

  @override
  ConsumerState<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends ConsumerState<CommentThread> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showBlocklistWarning = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocusInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // UX friction reduction only — the trigger is what actually
    // enforces this, and still runs regardless of what happens here
    // (e.g. if this client's cached blocklist is stale because admin
    // just added a term).
    final terms = ref.read(commentBlocklistProvider).valueOrNull ?? const [];
    if (commentMatchesBlocklist(text, terms)) {
      setState(() => _showBlocklistWarning = true);
      return;
    }
    if (_showBlocklistWarning) setState(() => _showBlocklistWarning = false);

    final created = await ref
        .read(commentControllerProvider.notifier)
        .postComment(trekId: widget.trekId, commentText: text);

    if (!mounted) return;

    if (created != null) {
      _controller.clear();
      _focusNode.unfocus();
      return;
    }

    final error = ref.read(commentControllerProvider).error;
    debugPrint('CommentThread: failed to post comment: $error');
    final message =
        error is CommentBlocklistException ? error.toString() : 'Could not post your comment. Please try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  void _guardedFocus(BuildContext context) {
    AuthGuard.requireAuth(
      context,
      returnPath: '${AppConstants.trekDetailLocation(widget.trekId)}?comment=1',
      onAuthenticated: _focusNode.requestFocus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSignedIn = ref.watch(supabaseClientProvider).auth.currentUser != null;
    final isSaving = ref.watch(commentControllerProvider).isLoading;
    final commentsAsync = ref.watch(trekCommentsProvider(widget.trekId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSignedIn)
          _CommentInput(
            controller: _controller,
            focusNode: _focusNode,
            isSaving: isSaving,
            showBlocklistWarning: _showBlocklistWarning,
            onChanged: (_) {
              if (_showBlocklistWarning) setState(() => _showBlocklistWarning = false);
            },
            onSubmit: _submit,
          )
        else
          _SignInToComment(onTap: () => _guardedFocus(context)),
        const SizedBox(height: 16),
        commentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) {
            debugPrint('CommentThread: failed to load comments for ${widget.trekId}: $error');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Could not load comments.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(trekCommentsProvider(widget.trekId)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
          data: (comments) {
            if (comments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No comments yet — be the first to share your thoughts.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              );
            }
            return Column(
              children: [
                for (final comment in comments) ...[
                  CommentTile(comment: comment),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.focusNode,
    required this.isSaving,
    required this.showBlocklistWarning,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSaving;
  final bool showBlocklistWarning;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(
            hintText: 'Share your thoughts on this trek…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorText: showBlocklistWarning
                ? 'This comment may contain inappropriate language.'
                : null,
            errorMaxLines: 2,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: isSaving ? null : onSubmit,
            icon: isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: const Text('Post'),
          ),
        ),
      ],
    );
  }
}

class _SignInToComment extends StatelessWidget {
  const _SignInToComment({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.forum_outlined, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sign in to leave a comment',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
