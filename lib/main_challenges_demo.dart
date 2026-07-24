import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/shared_preferences_provider.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/activity/domain/repositories/activity_provider.dart';
import 'package:doon_walkers/features/activity/presentation/providers/activity_providers.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_progress.dart';
import 'package:doon_walkers/features/challenges/domain/entities/challenge_tier_achievement.dart';
import 'package:doon_walkers/features/challenges/domain/entities/leaderboard_entry.dart';
import 'package:doon_walkers/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:doon_walkers/features/challenges/presentation/screens/challenge_detail_screen.dart';
import 'package:doon_walkers/features/challenges/presentation/screens/challenge_leaderboard_screen.dart';
import 'package:doon_walkers/features/challenges/presentation/screens/challenges_screen.dart';
import 'package:doon_walkers/features/challenges/presentation/screens/my_challenge_achievements_screen.dart';
import 'package:doon_walkers/features/challenges/presentation/widgets/tier_celebration_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Isolated review harness for the Redesign Phase 4 Challenges screens.
/// Renders the real screens/animation with mock data via Riverpod
/// overrides, offline. `flutter run -t lib/main_challenges_demo.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: 'https://demo.supabase.co', publishableKey: 'demo');
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isAdminProvider.overrideWith((ref) => ref.watch(_demoIsAdmin)),
        isSignedInProvider.overrideWith((ref) => ref.watch(_demoSignedIn)),
        activeChallengesProvider.overrideWith((ref) async => _active),
        adminAllChallengesProvider.overrideWith((ref) async => _all),
        challengeByIdProvider.overrideWith((ref, id) => _byId[id]),
        // A guest has no progress rows (the RPC requires auth) — mirror
        // that so guest cards show the sign-in prompt with no tier badge.
        myChallengeProgressProvider.overrideWith(
          (ref) async => ref.watch(_demoSignedIn) ? _progress : const [],
        ),
        challengeLeaderboardProvider.overrideWith((ref, id) async => _leaderboard),
        myTierHistoryProvider.overrideWith((ref) async => _history),
        // Activity banner → "synced" state, no Health Connect needed.
        activityAvailabilityProvider.overrideWith((ref) async => ActivityAvailability.available),
        activityPermissionGrantedProvider.overrideWith((ref) async => true),
        lastActivitySyncProvider.overrideWith(
          (ref) async => DateTime.now().subtract(const Duration(minutes: 8)),
        ),
      ],
      child: const _ChallengesDemoApp(),
    ),
  );
}

// ── Demo state ───────────────────────────────────────────────────────

final _demoIsAdmin = StateProvider<bool>((ref) => false);
final _demoSignedIn = StateProvider<bool>((ref) => true);

// ── Demo data ────────────────────────────────────────────────────────

List<ChallengeTierThreshold> _tiers(String cid, List<double> v) => [
  ChallengeTierThreshold(id: '${cid}b', challengeId: cid, tier: ChallengeTier.bronze, thresholdValue: v[0]),
  ChallengeTierThreshold(id: '${cid}s', challengeId: cid, tier: ChallengeTier.silver, thresholdValue: v[1]),
  ChallengeTierThreshold(id: '${cid}g', challengeId: cid, tier: ChallengeTier.gold, thresholdValue: v[2]),
  ChallengeTierThreshold(id: '${cid}p', challengeId: cid, tier: ChallengeTier.platinum, thresholdValue: v[3]),
];

final _chSteps = Challenge(
  id: 'steps',
  title: 'Daily Step Goal',
  description: 'Rack up steps every day — walking to the chai stall counts.',
  metric: ChallengeMetric.dailySteps,
  timeWindow: ChallengeTimeWindow.daily,
  icon: 'run',
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  tiers: _tiers('steps', [5000, 8000, 10000, 15000]),
);

final _chDistance = Challenge(
  id: 'distance',
  title: 'Weekly Distance',
  description: 'Cover ground on foot across the week.',
  metric: ChallengeMetric.dailyDistanceKm,
  timeWindow: ChallengeTimeWindow.weekly,
  icon: 'walk',
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  tiers: _tiers('distance', [10, 25, 50, 100]),
);

final _chStreak = Challenge(
  id: 'streak',
  title: 'Activity Streak',
  description: 'Keep your run of active days alive.',
  metric: ChallengeMetric.activeStreakDays,
  timeWindow: ChallengeTimeWindow.allTime,
  icon: 'fire',
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  tiers: _tiers('streak', [3, 7, 14, 30]),
);

final _chCalories = Challenge(
  id: 'calories',
  title: 'Monthly Burn',
  description: 'Burn calories through movement this month.',
  metric: ChallengeMetric.caloriesBurned,
  timeWindow: ChallengeTimeWindow.monthly,
  icon: 'terrain',
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  tiers: _tiers('calories', [5000, 15000, 30000, 50000]),
);

final _chDraft = Challenge(
  id: 'draft',
  title: 'Summer Streak (unreleased)',
  description: 'A seasonal challenge still being set up.',
  metric: ChallengeMetric.weeklySteps,
  timeWindow: ChallengeTimeWindow.weekly,
  icon: 'star',
  isActive: false,
  createdAt: DateTime(2026, 1, 1),
  tiers: _tiers('draft', [20000, 50000, 80000, 120000]),
);

final _active = <Challenge>[_chSteps, _chDistance, _chStreak, _chCalories];
final _all = <Challenge>[_chDraft, ..._active];
final _byId = {for (final c in _all) c.id: c};

// Genuine progress: Silver on steps (→ Gold), Gold on distance (→ Platinum),
// maxed Platinum on streak, and no tier yet on calories (→ Bronze).
final _progress = <ChallengeProgress>[
  const ChallengeProgress(challengeId: 'steps', currentValue: 9200, currentTier: ChallengeTier.silver),
  const ChallengeProgress(challengeId: 'distance', currentValue: 62, currentTier: ChallengeTier.gold),
  const ChallengeProgress(challengeId: 'streak', currentValue: 30, currentTier: ChallengeTier.platinum),
  const ChallengeProgress(challengeId: 'calories', currentValue: 0, currentTier: null),
];

// Leaderboard rows carry ONLY name/rank/score — the RPC contract. Opted-out
// users are excluded server-side, so they never appear here at all.
final _leaderboard = <LeaderboardEntry>[
  const LeaderboardEntry(displayName: 'Aarav Mehta', rank: 1, score: 15230),
  const LeaderboardEntry(displayName: 'Meera Kapoor', rank: 2, score: 12980),
  const LeaderboardEntry(displayName: 'Rohit Sharma', rank: 3, score: 11200),
  const LeaderboardEntry(displayName: 'Priya Nair', rank: 4, score: 9800),
  const LeaderboardEntry(displayName: 'You', rank: 5, score: 9200),
  const LeaderboardEntry(displayName: 'Karan Singh', rank: 6, score: 7400),
];

final _history = <ChallengeTierAchievement>[
  ChallengeTierAchievement(challengeId: 'streak', tier: ChallengeTier.platinum, achievedAt: DateTime(2026, 7, 20)),
  ChallengeTierAchievement(challengeId: 'distance', tier: ChallengeTier.gold, achievedAt: DateTime(2026, 7, 12)),
  ChallengeTierAchievement(challengeId: 'steps', tier: ChallengeTier.silver, achievedAt: DateTime(2026, 6, 30)),
];

// ── App ──────────────────────────────────────────────────────────────

class _ChallengesDemoApp extends StatelessWidget {
  const _ChallengesDemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoonWalkers · Challenges',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const _DemoHub(),
    );
  }
}

class _DemoHub extends ConsumerWidget {
  const _DemoHub();

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(_demoIsAdmin);
    final signedIn = ref.watch(_demoSignedIn);

    return Scaffold(
      appBar: AppBar(title: const Text('Challenges · Phase 4 demo')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _ToggleCard(
            label: signedIn ? 'Signed-in member' : 'Guest',
            icon: signedIn ? AppIcons.person : AppIcons.lock,
            accent: signedIn ? AppColors.primary : AppColors.textSecondary,
            value: signedIn,
            onChanged: (v) => ref.read(_demoSignedIn.notifier).state = v,
          ),
          const SizedBox(height: AppSpacing.md),
          _ToggleCard(
            label: isAdmin ? 'Admin' : 'Member role',
            icon: isAdmin ? AppIcons.medal : AppIcons.group,
            accent: isAdmin ? AppColors.accent : AppColors.primary,
            value: isAdmin,
            onChanged: (v) => ref.read(_demoIsAdmin.notifier).state = v,
          ),
          const SizedBox(height: AppSpacing.lg),
          _HubButton(label: 'Challenges list', icon: AppIcons.challenges, onTap: () => _open(context, const ChallengesScreen())),
          _HubButton(label: 'Challenge detail (Steps → Gold)', icon: AppIcons.run, onTap: () => _open(context, const ChallengeDetailScreen(challengeId: 'steps'))),
          _HubButton(label: 'Challenge detail (maxed Platinum)', icon: AppIcons.streak, onTap: () => _open(context, const ChallengeDetailScreen(challengeId: 'streak'))),
          _HubButton(label: 'Leaderboard', icon: AppIcons.leaderboard, onTap: () => _open(context, const ChallengeLeaderboardScreen(challengeId: 'steps'))),
          _HubButton(label: 'My Achievements', icon: AppIcons.medal, onTap: () => _open(context, const MyChallengeAchievementsScreen())),
          const Divider(height: AppSpacing.xxxl),
          Text('Tier-achievement animation', style: AppTextStyles.secondary(AppTextStyles.labelMedium)),
          const SizedBox(height: AppSpacing.sm),
          for (final tier in ChallengeTier.values)
            _HubButton(
              label: 'Play ${tier.label} celebration',
              icon: AppIcons.celebrate,
              onTap: () => showTierCelebration(context, challenge: _chSteps, tier: tier),
            ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurEnabled: false,
      glowColor: accent,
      child: Row(
        children: [
          AppIcon(icon, color: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTextStyles.titleMedium)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _HubButton extends StatelessWidget {
  const _HubButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassCard(
        blurEnabled: false,
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            AppIcon(icon, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTextStyles.titleSmall)),
            const AppIcon(AppIcons.chevronRight, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
