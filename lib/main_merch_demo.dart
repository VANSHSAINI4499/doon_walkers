import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/auth/data/models/user_model.dart';
import 'package:doon_walkers/features/auth/domain/entities/user_entity.dart';
import 'package:doon_walkers/features/merchandise/data/repositories/merch_inquiry_repository_impl.dart';
import 'package:doon_walkers/features/merchandise/data/repositories/wishlist_repository_impl.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/merch_inquiry.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/wishlist_item.dart';
import 'package:doon_walkers/features/merchandise/domain/repositories/merch_inquiry_repository.dart';
import 'package:doon_walkers/features/merchandise/domain/repositories/wishlist_repository.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/merch_inquiry_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/product_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/wishlist_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/admin_merch_inquiries_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/merchandise_catalog_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/screens/product_detail_screen.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/merch_inquiry_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Isolated review harness for the Redesign Phase 6 Merchandise module.
/// Renders the real catalog / detail / inquiry-form / admin-roster with
/// mock repositories, offline. `flutter run -t lib/main_merch_demo.dart`.
const _origin = 'http://localhost:8905';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: 'https://demo.supabase.co', publishableKey: 'demo');
  // Overrides at the ROOT scope so every pushed route (which are siblings
  // of the hub in the Navigator, outside `home`) inherits them.
  runApp(ProviderScope(overrides: _overrides, child: const _MerchDemoApp()));
}

final _demoIsAdmin = StateProvider<bool>((ref) => false);

// ── Mutable demo state the fake repos read/write ─────────────────────
final Set<String> _wishlist = {'beanie'};
final List<MerchInquiry> _inquiries = [];

// ── Demo products ────────────────────────────────────────────────────
ProductImage _img(String pid, String file, int order) => ProductImage(
  id: '$pid-$order',
  productId: pid,
  imageUrl: '$_origin/demo_assets/$file',
  uploadedAt: DateTime(2026, 1, order + 1),
);

ProductVariant _variant(String pid, String size, int stock) =>
    ProductVariant(id: '$pid-$size', productId: pid, size: size, stockQuantity: stock);

final _tee = Product(
  id: 'tee',
  name: 'Doon Walkers Trail Tee',
  description: 'Breathable, quick-dry cotton blend with the trail crest on the chest. '
      'Built for long ridge days and lazy chai afternoons alike.',
  price: 799,
  category: ProductCategory.apparel,
  stockQuantity: 0,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  variants: [_variant('tee', 'S', 4), _variant('tee', 'M', 6), _variant('tee', 'L', 0)],
  images: [_img('tee', 'tee1.jpg', 0), _img('tee', 'tee2.jpg', 1)],
);

final _beanie = Product(
  id: 'beanie',
  name: 'Summit Beanie',
  description: 'Warm ribbed knit for cold summit mornings.',
  price: 499,
  category: ProductCategory.headwear,
  stockQuantity: 12,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  images: [_img('beanie', 'beanie.jpg', 0)],
);

final _flask = Product(
  id: 'flask',
  name: 'Trail Flask 750ml',
  description: 'Vacuum-insulated steel flask.',
  price: 1299,
  category: ProductCategory.drinkware,
  stockQuantity: 0,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
  images: [_img('flask', 'flask.jpg', 0)],
);

final _stickers = Product(
  id: 'stickers',
  name: 'Trail Sticker Pack',
  description: '',
  price: 149,
  category: ProductCategory.stickers,
  stockQuantity: 40,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

final _hoodie = Product(
  id: 'hoodie',
  name: 'Winter Hoodie (unreleased)',
  description: 'Heavyweight fleece hoodie — dropping this winter.',
  price: 1899,
  category: ProductCategory.apparel,
  stockQuantity: 0,
  isActive: false,
  createdAt: DateTime(2026, 1, 1),
  variants: [_variant('hoodie', 'M', 5), _variant('hoodie', 'L', 5)],
  images: [_img('hoodie', 'hoodie.jpg', 0)],
);

final _active = <Product>[_tee, _beanie, _flask, _stickers];
final _all = <Product>[_hoodie, ..._active];
final _byId = {for (final p in _all) p.id: p};

// ── Fake repositories ────────────────────────────────────────────────
class _FakeWishlistRepository implements WishlistRepository {
  @override
  Future<WishlistItem> addToWishlist(String productId) async {
    _wishlist.add(productId);
    return WishlistItem(
      id: 'w-$productId',
      userId: 'u1',
      productId: productId,
      createdAt: DateTime.now(),
      product: _byId[productId]!,
    );
  }

  @override
  Future<void> removeFromWishlist(String productId) async => _wishlist.remove(productId);

  @override
  Future<bool> isWishlisted(String productId) async => _wishlist.contains(productId);

  @override
  Future<List<WishlistItem>> fetchMyWishlist() async => _wishlist
      .map((id) => WishlistItem(
            id: 'w-$id',
            userId: 'u1',
            productId: id,
            createdAt: DateTime.now(),
            product: _byId[id]!,
          ))
      .toList();
}

class _FakeMerchInquiryRepository implements MerchInquiryRepository {
  @override
  Future<MerchInquiry> createInquiry({
    required String productId,
    String? variantId,
    required int quantity,
    String? note,
    required String phoneNumber,
  }) async {
    final product = _byId[productId]!;
    final variant = product.variants.where((v) => v.id == variantId).firstOrNull;
    final inquiry = MerchInquiry(
      id: 'i${_inquiries.length + 1}',
      userId: 'u1',
      productId: productId,
      variantId: variantId,
      quantity: quantity,
      note: note,
      status: MerchInquiryStatus.pending,
      createdAt: DateTime.now(),
      productName: product.name,
      variantSize: variant?.size,
      userName: 'Asha Rawat',
      userEmail: 'asha.rawat@example.com',
      phoneNumber: phoneNumber,
    );
    _inquiries.insert(0, inquiry);
    return inquiry;
  }

  @override
  Future<List<MerchInquiry>> fetchAllInquiries() async => List.of(_inquiries);

  @override
  Future<List<MerchInquiry>> fetchMyInquiries() async => List.of(_inquiries);

  @override
  Future<void> updateStatus(String id, MerchInquiryStatus status) async {}
}

List<Override> get _overrides => [
  isAdminProvider.overrideWith((ref) => ref.watch(_demoIsAdmin)),
  currentUserProvider.overrideWith(
    (ref) => Stream.value(UserModel(
      id: 'u1',
      name: 'Asha Rawat',
      email: 'asha.rawat@example.com',
      phone: '+91 98765 43210',
      role: ref.watch(_demoIsAdmin) ? UserRole.admin : UserRole.user,
      createdAt: DateTime(2025, 3, 1),
    )),
  ),
  activeProductsProvider.overrideWith((ref) async => _active),
  adminAllProductsProvider.overrideWith((ref) async => _all),
  productByIdProvider.overrideWith((ref, id) => _byId[id]),
  isProductWishlistedProvider.overrideWith((ref, id) async => _wishlist.contains(id)),
  wishlistRepositoryProvider.overrideWithValue(_FakeWishlistRepository()),
  merchInquiryRepositoryProvider.overrideWithValue(_FakeMerchInquiryRepository()),
  allMerchInquiriesProvider.overrideWith((ref) async => List.of(_inquiries)),
];

// ── App ──────────────────────────────────────────────────────────────
class _MerchDemoApp extends StatelessWidget {
  const _MerchDemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoonWalkers · Merch',
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

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(_demoIsAdmin);
    return Scaffold(
      appBar: AppBar(title: const Text('Merch · Phase 6 demo')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GlassCard(
            blurEnabled: false,
            glowColor: isAdmin ? AppColors.accent : AppColors.primary,
            child: Row(
              children: [
                AppIcon(isAdmin ? AppIcons.medal : AppIcons.person, color: isAdmin ? AppColors.accent : AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(isAdmin ? 'Viewing as: Admin' : 'Viewing as: Member', style: AppTextStyles.titleMedium)),
                Switch(value: isAdmin, onChanged: (v) => ref.read(_demoIsAdmin.notifier).state = v),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _HubButton(label: 'Catalog', icon: AppIcons.store, onTap: () => _open(context, const MerchandiseCatalogScreen())),
          _HubButton(label: 'Detail — Trail Tee (variants)', icon: AppIcons.bag, onTap: () => _open(context, const ProductDetailScreen(productId: 'tee'))),
          _HubButton(label: 'Detail — Beanie (no variants)', icon: AppIcons.bag, onTap: () => _open(context, const ProductDetailScreen(productId: 'beanie'))),
          _HubButton(label: 'Detail — Flask (out of stock)', icon: AppIcons.cart, onTap: () => _open(context, const ProductDetailScreen(productId: 'flask'))),
          _HubButton(label: 'Detail — Hoodie (draft, admin)', icon: AppIcons.editNote, onTap: () => _open(context, const ProductDetailScreen(productId: 'hoodie'))),
          _HubButton(label: 'Admin inquiry roster', icon: AppIcons.forum, onTap: () => _open(context, const AdminMerchInquiriesScreen())),
          const Divider(height: AppSpacing.xxxl),
          _HubButton(label: 'Buy Now inquiry form (variants)', icon: AppIcons.send, onTap: () => showMerchInquiryFormSheet(context, product: _tee)),
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
