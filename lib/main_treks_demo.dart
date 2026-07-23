import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/comments/domain/entities/comment.dart';
import 'package:doon_walkers/features/comments/presentation/providers/comment_providers.dart';
import 'package:doon_walkers/features/gallery/presentation/providers/gallery_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:doon_walkers/features/registrations/presentation/widgets/registration_form_sheet.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/trek_detail_screen.dart';
import 'package:doon_walkers/features/trek_library/presentation/screens/trek_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Isolated review harness for the Redesign Phase 3 Treks screens.
///
/// Renders the real [TrekLibraryScreen], [TrekDetailScreen] and the real
/// registration form sheet with mock data injected via Riverpod overrides,
/// offline. A small demo hub navigates to each scenario the phase brief
/// asks to see (grid, free/fee register flows, admin inline controls,
/// loading skeleton). Production entrypoint is `lib/main.dart`.
///
/// ```
/// flutter run -t lib/main_treks_demo.dart
/// ```
const _origin = 'http://localhost:8902';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Dummy init so the widgets that read Supabase.instance directly
  // (comment thread/tile) resolve to a guest session. Never connects.
  await Supabase.initialize(url: 'https://demo.supabase.co', publishableKey: 'demo');
  runApp(
    ProviderScope(
      overrides: _overrides,
      child: const _TreksDemoApp(),
    ),
  );
}

// ── Demo data ────────────────────────────────────────────────────────

/// Runtime admin toggle; [isAdminProvider] is overridden to follow it.
final _demoIsAdmin = StateProvider<bool>((ref) => false);

DateTime _daysFromNow(int d) => DateTime.now().add(Duration(days: d));

final _tFree = Trek(
  id: 'free',
  title: 'Roopkund Skeleton Lake',
  description:
      'A high-altitude glacial lake ringed by legend, reached over meadows, '
      'oak forest and a final snowbound push to 5,029 m. Eight days on the '
      'trail, one unforgettable ridge dawn — arguably the most storied trek '
      'in the Garhwal Himalaya.',
  difficulty: TrekDifficulty.hard,
  distanceKm: 53,
  durationDays: 8,
  altitudeM: 5029,
  bestSeason: 'May–Jun · Sep–Oct',
  thingsToCarry:
      'Layered insulation, waterproof shell, sturdy boots, headlamp, '
      'sunglasses & sunscreen, refillable bottle, personal medication.',
  googleMapLink: 'https://maps.google.com/?q=Roopkund',
  coverImage: '$_origin/demo_assets/cover_roopkund.jpg',
  isPublished: true,
  createdAt: DateTime(2026, 1, 1),
  trekDate: _daysFromNow(24),
);

final _tFee = Trek(
  id: 'fee',
  title: 'Kedarkantha Winter Summit',
  description:
      'The classic first-timer\'s snow summit: pine forest, frozen clearings '
      'and a sunrise summit push to 3,800 m.',
  difficulty: TrekDifficulty.moderate,
  distanceKm: 20,
  durationDays: 6,
  altitudeM: 3800,
  bestSeason: 'Dec–Mar',
  thingsToCarry: 'Gaiters, microspikes, thermals, gloves, balaclava.',
  coverImage: '$_origin/demo_assets/cover_kedar.jpg',
  isPublished: true,
  createdAt: DateTime(2026, 1, 1),
  trekDate: _daysFromNow(34),
  registrationFee: 1500,
  paymentQrCode: '$_origin/demo_assets/qr.jpg',
);

final _tDone = Trek(
  id: 'done',
  title: 'Valley of Flowers',
  description: 'A monsoon bloom of endemic alpine flowers in a UNESCO valley.',
  difficulty: TrekDifficulty.easy,
  distanceKm: 38,
  durationDays: 5,
  altitudeM: 3658,
  bestSeason: 'Jul–Aug',
  coverImage: '$_origin/demo_assets/cover_valley.jpg',
  isPublished: true,
  createdAt: DateTime(2026, 1, 1),
  trekDate: _daysFromNow(-26),
);

final _tShort = Trek(
  id: 'short',
  title: 'Nag Tibba Night Trek',
  description: 'A quick overnighter.',
  difficulty: TrekDifficulty.easy,
  distanceKm: 16,
  durationDays: 2,
  isPublished: true,
  createdAt: DateTime(2026, 1, 1),
);

final _tNoDesc = Trek(
  id: 'nodesc',
  title: 'Har Ki Dun',
  description: '',
  difficulty: TrekDifficulty.moderate,
  distanceKm: 47,
  durationDays: 7,
  coverImage: '$_origin/demo_assets/cover_nag.jpg',
  isPublished: true,
  createdAt: DateTime(2026, 1, 1),
);

final _tDraft = Trek(
  id: 'draft',
  title: 'Brahmatal (unreleased)',
  description: 'A winter ridge trek with twin summit views of Trishul & Nanda Ghunti.',
  difficulty: TrekDifficulty.moderate,
  distanceKm: 24,
  durationDays: 6,
  altitudeM: 3734,
  coverImage: '$_origin/demo_assets/cover_nag.jpg',
  isPublished: false,
  createdAt: DateTime(2026, 1, 1),
  trekDate: _daysFromNow(40),
);

final _published = <Trek>[_tFree, _tFee, _tDone, _tShort, _tNoDesc];
final _all = <Trek>[_tDraft, ..._published];
final _byId = {for (final t in [..._all]) t.id: t};

final _demoComments = <Comment>[
  Comment(
    id: 'c1',
    trekId: 'free',
    userId: 'u2',
    commentText: 'Did this last September — the final climb to the lake at dawn is unreal. Carry an extra layer!',
    isVisible: true,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    userName: 'Meera K.',
  ),
  Comment(
    id: 'c2',
    trekId: 'free',
    userId: 'u3',
    commentText: 'How cold does it get at the last campsite?',
    isVisible: true,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    userName: 'Rohit',
  ),
];

List<Override> get _overrides => [
  isAdminProvider.overrideWith((ref) => ref.watch(_demoIsAdmin)),
  publishedTreksProvider.overrideWith((ref) async => sortTreksForLibrary(_published)),
  adminAllTreksProvider.overrideWith((ref) async => sortTreksForLibrary(_all)),
  trekByIdProvider.overrideWith((ref, id) => _byId[id]),
  trekGalleryProvider.overrideWith((ref, id) async => const []),
  trekCommentsProvider.overrideWith((ref, id) async => id == 'free' ? _demoComments : const []),
  commentBlocklistProvider.overrideWith((ref) async => const <String>[]),
  myRegistrationForTrekProvider.overrideWith((ref, id) async => null),
];

// ── App ──────────────────────────────────────────────────────────────

class _TreksDemoApp extends StatelessWidget {
  const _TreksDemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoonWalkers · Treks',
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
    return Scaffold(
      appBar: AppBar(title: const Text('Treks · Phase 3 demo')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GlassCard(
            blurEnabled: false,
            glowColor: isAdmin ? AppColors.accent : AppColors.primary,
            child: Row(
              children: [
                AppIcon(isAdmin ? AppIcons.medal : AppIcons.person,
                    color: isAdmin ? AppColors.accent : AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    isAdmin ? 'Viewing as: Admin' : 'Viewing as: Member',
                    style: AppTextStyles.titleMedium,
                  ),
                ),
                Switch(
                  value: isAdmin,
                  onChanged: (v) => ref.read(_demoIsAdmin.notifier).state = v,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _HubButton(
            label: 'Trek Library grid',
            icon: AppIcons.treks,
            onTap: () => _open(context, const TrekLibraryScreen()),
          ),
          _HubButton(
            label: 'Detail — free upcoming trek',
            icon: AppIcons.hiking,
            onTap: () => _open(context, const TrekDetailScreen(trekId: 'free')),
          ),
          _HubButton(
            label: 'Detail — fee (₹) upcoming trek',
            icon: AppIcons.payment,
            onTap: () => _open(context, const TrekDetailScreen(trekId: 'fee')),
          ),
          _HubButton(
            label: 'Detail — completed trek',
            icon: AppIcons.eventBusy,
            onTap: () => _open(context, const TrekDetailScreen(trekId: 'done')),
          ),
          _HubButton(
            label: 'Detail — draft (admin only)',
            icon: AppIcons.editNote,
            onTap: () => _open(context, const TrekDetailScreen(trekId: 'draft')),
          ),
          const Divider(height: AppSpacing.xxxl),
          _HubButton(
            label: 'Register form — FREE trek',
            icon: AppIcons.checkCircle,
            onTap: () => showRegistrationFormSheet(context, trek: _tFree),
          ),
          _HubButton(
            label: 'Register form — FEE trek (QR + screenshot)',
            icon: AppIcons.qr,
            onTap: () => showRegistrationFormSheet(context, trek: _tFee),
          ),
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
