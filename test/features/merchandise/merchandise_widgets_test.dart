// Guards the Merchandise module's most redesign-sensitive conditionals:
// the ProductCard draft marker (admin-view-of-inactive only), and the
// ProductBuyButton stock gating (Buy Now enabled in stock, disabled "Out
// of Stock" otherwise — including the per-variant stock rule). WHEN these
// appear must be unchanged.

import 'package:doon_walkers/core/theme/app_theme.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_buy_button.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product({
  bool active = true,
  int stock = 5,
  List<ProductVariant> variants = const [],
  String name = 'Trail Tee',
  String description = 'A comfy trail tee.',
}) => Product(
  id: 'p1',
  name: name,
  description: description,
  price: 799,
  category: ProductCategory.apparel,
  stockQuantity: stock,
  isActive: active,
  createdAt: DateTime(2026, 1, 1),
  variants: variants,
);

ProductVariant _variant(String size, int stock) =>
    ProductVariant(id: 'v-$size', productId: 'p1', size: size, stockQuantity: stock);

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: 320, child: child)),
  ),
);

void main() {
  group('ProductCard draft marker', () {
    testWidgets('admin view of an inactive product shows Draft', (tester) async {
      await tester.pumpWidget(_host(
        ProductCard(product: _product(active: false), onTap: () {}, adminActions: const SizedBox(width: 24, height: 24)),
      ));
      await tester.pump();
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('non-admin view of an inactive product shows no Draft', (tester) async {
      await tester.pumpWidget(_host(
        ProductCard(product: _product(active: false), onTap: () {}),
      ));
      await tester.pump();
      expect(find.text('Draft'), findsNothing);
    });

    testWidgets('admin view of an active product shows no Draft', (tester) async {
      await tester.pumpWidget(_host(
        ProductCard(product: _product(active: true), onTap: () {}, adminActions: const SizedBox(width: 24, height: 24)),
      ));
      await tester.pump();
      expect(find.text('Draft'), findsNothing);
    });

    testWidgets('shows category and stock badges and the price', (tester) async {
      await tester.pumpWidget(_host(ProductCard(product: _product(), onTap: () {})));
      await tester.pump();
      expect(find.text('Apparel'), findsOneWidget);
      expect(find.text('In Stock'), findsOneWidget);
      expect(find.text('₹799'), findsOneWidget);
    });
  });

  group('ProductBuyButton stock gating', () {
    testWidgets('in-stock (no variants) → enabled Buy Now', (tester) async {
      await tester.pumpWidget(_host(ProductBuyButton(product: _product(stock: 3))));
      await tester.pump();
      expect(find.text('Buy Now'), findsOneWidget);
      expect(find.text('Out of Stock'), findsNothing);
    });

    testWidgets('out-of-stock (no variants) → Out of Stock', (tester) async {
      await tester.pumpWidget(_host(ProductBuyButton(product: _product(stock: 0))));
      await tester.pump();
      expect(find.text('Out of Stock'), findsOneWidget);
      expect(find.text('Buy Now'), findsNothing);
    });

    testWidgets('any in-stock variant → Buy Now (per-variant stock rule)', (tester) async {
      await tester.pumpWidget(_host(ProductBuyButton(
        // The product-level stockQuantity is ignored once variants exist.
        product: _product(stock: 0, variants: [_variant('S', 0), _variant('M', 2)]),
      )));
      await tester.pump();
      expect(find.text('Buy Now'), findsOneWidget);
    });

    testWidgets('all variants out of stock → Out of Stock', (tester) async {
      await tester.pumpWidget(_host(ProductBuyButton(
        product: _product(stock: 99, variants: [_variant('S', 0), _variant('M', 0)]),
      )));
      await tester.pump();
      expect(find.text('Out of Stock'), findsOneWidget);
    });
  });
}
