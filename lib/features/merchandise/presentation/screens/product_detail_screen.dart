import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/core/widgets/section_title.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/product_providers.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/merch_inquiry_form_sheet.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_admin_actions.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_buy_button.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_category_badge.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_images_section.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/stock_status_badge.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/wishlist_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full product view. `product == null` covers two cases RLS makes
/// indistinguishable on purpose — the id doesn't exist, or it's a draft a
/// non-admin isn't allowed to see — both render the same "not found" state.
///
/// Redesign Phase 6: rebuilt on the design system (hero cover with the
/// shared card→detail flight, glass badges, skeleton loading). The
/// auto-open-buy-form flow, the admin-only hiding of the wishlist/buy
/// controls, and every other conditional are unchanged.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.openBuyForm = false,
    this.openWishlist = false,
  });

  final String productId;

  /// Set from the `?buy=1` sign-in return flag.
  final bool openBuyForm;

  /// Set from the `?wishlist=1` sign-in return flag.
  final bool openWishlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(productId));

    return Scaffold(
      body: productAsync.when(
        loading: () => const _ProductDetailSkeleton(),
        error: (error, stack) => _DetailMessage(
          icon: AppIcons.error,
          title: 'Could not load this product.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(productByIdProvider(productId)),
        ),
        data: (product) {
          if (product == null) {
            return const _DetailMessage(
              icon: AppIcons.searchOff,
              title: 'Product not found.',
            );
          }
          return _ProductDetailBody(
            product: product,
            isAdmin: ref.watch(isAdminProvider),
            openBuyForm: openBuyForm,
            openWishlist: openWishlist,
          );
        },
      ),
    );
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.icon, required this.title, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 48, color: AppColors.textDisabled),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                PremiumButton(
                  label: actionLabel!,
                  icon: AppIcons.refresh,
                  size: PremiumButtonSize.small,
                  onPressed: onAction,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              PremiumButton(
                label: 'Back',
                icon: AppIcons.back,
                variant: PremiumButtonVariant.ghost,
                size: PremiumButtonSize.small,
                onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductDetailBody extends ConsumerStatefulWidget {
  const _ProductDetailBody({
    required this.product,
    required this.isAdmin,
    required this.openBuyForm,
    required this.openWishlist,
  });

  final Product product;

  /// Drives whether inline management controls render.
  final bool isAdmin;

  final bool openBuyForm;
  final bool openWishlist;

  @override
  ConsumerState<_ProductDetailBody> createState() => _ProductDetailBodyState();
}

class _ProductDetailBodyState extends ConsumerState<_ProductDetailBody> {
  /// Auto-opens the inquiry sheet once, from the `?buy=1` sign-in return
  /// flag — initState's once-per-State-lifetime guarantee suffices since
  /// `product` is already resolved by the time this widget is built.
  @override
  void initState() {
    super.initState();
    if (widget.openBuyForm && !widget.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final submitted = await showMerchInquiryFormSheet(context, product: widget.product);
        if (submitted == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Thanks! We'll be in touch to arrange payment and pickup."),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isAdmin = widget.isAdmin;
    final coverImage = product.coverImageUrl;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: AppColors.white),
          actions: [
            if (isAdmin)
              ProductAdminActions(
                product: product,
                iconColor: AppColors.white,
                onDeleted: () {
                  if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                },
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                AppHero(
                  tag: AppHeroTags.productImage(product.id),
                  fromRadius: 0,
                  toRadius: 0,
                  child: (coverImage == null || coverImage.isEmpty)
                      ? const _CoverFallback(icon: AppIcons.bag)
                      : Image.network(
                          coverImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const _CoverFallback(icon: AppIcons.imageBroken),
                        ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99000000), Color(0x00000000), Color(0xFF090909)],
                      stops: [0, 0.4, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Only an admin can reach an inactive product (RLS).
                    if (isAdmin && !product.isActive) ...[
                      _DraftBanner(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(product.name, style: AppTextStyles.headlineSmall),
                        ),
                        // Admins manage the catalog, they don't wishlist
                        // from it — same convention as the Buy Now CTA.
                        if (!isAdmin) ...[
                          const SizedBox(width: AppSpacing.md),
                          WishlistButton(productId: product.id, autoAdd: widget.openWishlist),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        ProductCategoryBadge(category: product.category),
                        StockStatusBadge(isInStock: product.isInStock),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _formatPrice(product.price),
                      style: AppTextStyles.tinted(AppTextStyles.headlineMedium, AppColors.primary),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    if (product.hasVariants) ...[
                      const SectionTitle(title: 'Available Sizes', icon: AppIcons.distance),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: product.variants.map((v) => _SizeChip(variant: v)).toList(),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],

                    if (product.description.trim().isNotEmpty) ...[
                      const SectionTitle(title: 'Description', icon: AppIcons.book, accent: AppColors.secondary),
                      const SizedBox(height: AppSpacing.md),
                      Text(product.description, style: AppTextStyles.secondary(AppTextStyles.bodyLarge)),
                      const SizedBox(height: AppSpacing.xxl),
                    ],

                    // Buy Now — an inquiry-to-admin flow. Admins manage the
                    // catalog, they don't buy from it.
                    if (!isAdmin) ...[
                      ProductBuyButton(product: product),
                      const SizedBox(height: AppSpacing.xxl),
                    ],

                    const Divider(),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionTitle(title: 'Photos', icon: AppIcons.photo, accent: AppColors.accent),
                    const SizedBox(height: AppSpacing.md),
                    ProductImagesSection(
                      productId: product.id,
                      productName: product.name,
                      images: product.images,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price) =>
      '₹${price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2)}';
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A24), AppColors.background],
        ),
      ),
      child: Center(child: AppIcon(AppIcons.bag, size: 64, color: AppColors.textDisabled)),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blurEnabled: false,
      glowColor: AppColors.gold,
      glowOpacity: 0.12,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          const AppIcon(AppIcons.editNote, size: 18, color: AppColors.gold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Draft — not visible to members yet.',
              style: AppTextStyles.tinted(AppTextStyles.labelMedium, AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Informational size chip (not a selector — the size is chosen in the
/// inquiry form). Out-of-stock sizes are struck through in danger.
class _SizeChip extends StatelessWidget {
  const _SizeChip({required this.variant});

  final ProductVariant variant;

  @override
  Widget build(BuildContext context) {
    final inStock = variant.isInStock;
    final color = inStock ? AppColors.glassBorder : AppColors.danger.withValues(alpha: 0.5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color),
        color: inStock ? AppColors.card : AppColors.danger.withValues(alpha: 0.08),
      ),
      child: Text(
        variant.size,
        style: AppTextStyles.tinted(
          AppTextStyles.labelLarge,
          inStock ? AppColors.textPrimary : AppColors.danger,
        ).copyWith(decoration: inStock ? null : TextDecoration.lineThrough),
      ),
    );
  }
}

/// Skeleton for the product detail while it loads.
class _ProductDetailSkeleton extends StatelessWidget {
  const _ProductDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          SkeletonBox(height: 300, borderRadius: 0),
          Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 220, height: 28),
                SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    SkeletonBox(width: 80, height: 24, borderRadius: AppRadius.pill),
                    SizedBox(width: AppSpacing.sm),
                    SkeletonBox(width: 90, height: 24, borderRadius: AppRadius.pill),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                SkeletonBox(width: 100, height: 24),
                SizedBox(height: AppSpacing.xxl),
                SkeletonBox(width: 160, height: 20),
                SizedBox(height: AppSpacing.md),
                SkeletonText(lines: 3),
                SizedBox(height: AppSpacing.xxl),
                SkeletonBox(height: 56, borderRadius: AppRadius.md),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
