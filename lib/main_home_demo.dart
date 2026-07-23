import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/home/domain/entities/community_stats.dart';
import 'package:doon_walkers/features/home/presentation/providers/community_stats_provider.dart';
import 'package:doon_walkers/features/home/presentation/screens/home_screen.dart';
import 'package:doon_walkers/features/settings/domain/entities/app_settings.dart';
import 'package:doon_walkers/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Isolated review harness for the Redesign Phase 2 Home screen.
///
/// Renders the real [HomeScreen] with realistic mock data injected via
/// Riverpod overrides, inside a faithful copy of the AppShell chrome (dark
/// app bar + bottom nav), so Home can be judged exactly as a user sees it
/// — offline, with no real Supabase project. The production entrypoint is
/// `lib/main.dart`; this file is a review harness only.
///
/// ```
/// flutter run -t lib/main_home_demo.dart
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Dummy init so `Supabase.instance` exists for the widgets that read it
  // directly (JoinCommunitySection). It never connects — every data
  // provider Home uses is overridden below.
  await Supabase.initialize(url: 'https://demo.supabase.co', publishableKey: 'demo');

  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _demoSettings),
        communityStatsProvider.overrideWith((ref) => _demoStats),
        // Guest session, so Home shows the "Join the community" CTA.
        currentUserProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const _HomeDemoApp(),
    ),
  );
}

const _demoStats = CommunityStats(
  memberCount: 248,
  publishedTrekCount: 32,
  registrationCount: 1174,
);

const _demoSettings = AppSettings({
  'org_name': 'Doon Walkers',
  'org_tagline': 'Chase ridgelines, not deadlines.',
  'org_city': 'Dehradun',
  'org_state': 'Uttarakhand',
  'instagram_url': 'https://instagram.com/doonwalkers',
  'whatsapp_url': 'https://chat.whatsapp.com/demo',
  'contact_email': 'hello@doonwalkers.in',
  'contact_phone': '+91 98765 43210',
  'community_story':
      'Doon Walkers began with five friends and one shared trailhead above '
      'Dehradun. A decade of dawn starts later, we are a few hundred strong — '
      'still chasing the same first light on the same quiet ridgelines.',
  'founder_message':
      'The mountains do not care how fast you go, only that you keep showing '
      'up. Lace up, breathe deep, and let the trail do the rest.',
  'vision':
      'A generation of Doon that treats the Himalaya as home — and treads it '
      'like a guest.',
  'mission':
      'Make high-quality, low-impact trekking accessible to every walker in '
      'the valley, whatever their pace or budget.',
  'community_rules':
      'Leave no trace. Walk your own walk but never leave a walker behind. '
      'Respect the mountain, the locals, and each other.',
  'why_join':
      'Weekend treks, skill sessions, and a WhatsApp group that actually '
      'plans things. Come for the summits, stay for the chai at the top.',
});

class _HomeDemoApp extends StatelessWidget {
  const _HomeDemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoonWalkers · Home',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const _AppShellFrame(child: HomeScreen()),
    );
  }
}

/// A static, non-navigating stand-in for AppShell's chrome, so the demo
/// shows Home in its true frame (matching the AppShell legibility fix).
class _AppShellFrame extends StatelessWidget {
  const _AppShellFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Doon Walkers',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.white),
        ),
        actions: const [
          Icon(Icons.notifications_outlined, color: AppColors.white),
          SizedBox(width: AppSpacing.lg),
          Icon(Icons.menu, color: AppColors.white),
          SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.terrain), label: 'Treks'),
          NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Challenges'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
