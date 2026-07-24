import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/auth/data/models/user_model.dart';
import 'package:doon_walkers/features/auth/domain/entities/user_entity.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/wishlist_item.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/merch_inquiry_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/wishlist_providers.dart';
import 'package:doon_walkers/features/profile/presentation/screens/profile_screen.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration_stats.dart';
import 'package:doon_walkers/features/registrations/domain/entities/trekking_streak.dart';
import 'package:doon_walkers/features/registrations/presentation/providers/registration_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Isolated review harness for the Redesign Phase 5 Profile screen.
/// Renders the real [ProfileScreen] with mock data via Riverpod overrides,
/// offline. A Member/Admin toggle in the app bar confirms Send Notification
/// appears only for an admin. `flutter run -t lib/main_profile_demo.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: 'https://demo.supabase.co', publishableKey: 'demo');
  runApp(const ProviderScope(child: _ProfileDemoApp()));
}

final _demoIsAdmin = StateProvider<bool>((ref) => false);

UserModel _user(bool admin) => UserModel(
  id: 'u1',
  name: admin ? 'Priya Admin' : 'Asha Rawat',
  email: admin ? 'priya@doonwalkers.in' : 'asha.rawat@example.com',
  role: admin ? UserRole.admin : UserRole.user,
  createdAt: DateTime(2025, 3, 1),
  showOnLeaderboard: true,
);

const _stats = RegistrationStats(
  totalRegistered: 12,
  totalAttended: 7,
  upcoming: 2,
  cancelled: 1,
);

const _streak = TrekkingStreak(currentMonths: 4, longestMonths: 6);

Registration _reg(String id, String title, {String? screenshotUrl, int daysAgo = 10}) => Registration(
  id: id,
  trekId: 't-$id',
  userId: 'u1',
  paymentStatus: PaymentStatus.pending,
  createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
  userName: 'Asha Rawat',
  userEmail: 'asha.rawat@example.com',
  trekTitle: title,
  paymentScreenshotUrl: screenshotUrl,
);

final _registrations = <Registration>[
  _reg('1', 'Kedarkantha Winter Summit', screenshotUrl: 'proof.jpg', daysAgo: 4),
  _reg('2', 'Nag Tibba Night Trek', daysAgo: 18),
];

Product _product(String id, String name, double price) => Product(
  id: id,
  name: name,
  description: '',
  price: price,
  category: ProductCategory.apparel,
  stockQuantity: 10,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

final _wishlist = <WishlistItem>[
  WishlistItem(
    id: 'w1',
    userId: 'u1',
    productId: 'p1',
    createdAt: DateTime(2026, 6, 1),
    product: _product('p1', 'Doon Walkers Trail Tee', 799),
  ),
  WishlistItem(
    id: 'w2',
    userId: 'u1',
    productId: 'p2',
    createdAt: DateTime(2026, 6, 2),
    product: _product('p2', 'Summit Beanie', 499),
  ),
];

final _inquiries = <MerchInquiry>[
  MerchInquiry(
    id: 'i1',
    userId: 'u1',
    productId: 'p1',
    quantity: 1,
    status: MerchInquiryStatus.contacted,
    createdAt: DateTime.now().subtract(const Duration(days: 6)),
    productName: 'Doon Walkers Trail Tee',
    variantSize: 'M',
    userName: 'Asha Rawat',
    userEmail: 'asha.rawat@example.com',
  ),
];

List<Override> _overrides(bool admin) => [
  isAdminProvider.overrideWith((ref) => ref.watch(_demoIsAdmin)),
  currentUserProvider.overrideWith((ref) => Stream.value(_user(ref.watch(_demoIsAdmin)))),
  myRegistrationsProvider.overrideWith((ref) async => _registrations),
  myRegistrationStatsProvider.overrideWith((ref) async => _stats),
  myStreakProvider.overrideWith((ref) async => _streak),
  myWishlistProvider.overrideWith((ref) async => _wishlist),
  myMerchInquiriesProvider.overrideWith((ref) async => _inquiries),
];

class _ProfileDemoApp extends ConsumerWidget {
  const _ProfileDemoApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(_demoIsAdmin);
    return MaterialApp(
      title: 'DoonWalkers · Profile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      // Re-scope on toggle so every overridden provider re-reads the role.
      home: ProviderScope(
        key: ValueKey(admin),
        overrides: _overrides(admin),
        child: const _ProfileWithToggle(),
      ),
    );
  }
}

class _ProfileWithToggle extends ConsumerWidget {
  const _ProfileWithToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read the outer toggle through a fresh provider read — the inner
    // scope inherits it since it's declared above the app.
    return Stack(
      children: [
        const ProfileScreen(),
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: _RoleToggleChip(),
          ),
        ),
      ],
    );
  }
}

class _RoleToggleChip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(_demoIsAdmin);
    return Material(
      color: Colors.transparent,
      child: GlassCard(
        blurEnabled: false,
        glowColor: admin ? AppColors.accent : AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        onTap: () => ref.read(_demoIsAdmin.notifier).state = !admin,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(admin ? AppIcons.medal : AppIcons.person, size: 18, color: admin ? AppColors.accent : AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(admin ? 'Admin' : 'Member', style: AppTextStyles.labelMedium),
          ],
        ),
      ),
    );
  }
}
