import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Call-to-action card at the bottom of Home.
///
/// Design choice (flagged per the phase brief rather than assumed):
/// a signed-in member sees "You're a Member!" with a button that routes
/// to Profile, rather than a static no-op label — it gives them
/// somewhere useful to go instead of a dead end.
class JoinCommunitySection extends ConsumerWidget {
  const JoinCommunitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);
    final hasSession = Supabase.instance.client.auth.currentUser != null;

    // A signed-in user's public.users row hasn't resolved yet — avoid
    // flashing "guest" CTA copy at someone who's actually a member.
    if (hasSession && userAsync.isLoading && !userAsync.hasValue) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final isMember = userAsync.value != null;

    return Card(
      color: theme.colorScheme.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              isMember ? Icons.emoji_people_rounded : Icons.group_add_rounded,
              size: 40,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 12),
            Text(
              isMember ? "You're a Member!" : 'Join Our Community',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isMember
                  ? 'Manage your profile and keep an eye out for new treks.'
                  : 'Create a free account to register for treks, comment, and get community updates.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => isMember
                  ? context.go(AppConstants.routeProfile)
                  : context.push(AppConstants.routeSignUp),
              child: Text(isMember ? 'Go to Profile' : 'Join Community'),
            ),
          ],
        ),
      ),
    );
  }
}
