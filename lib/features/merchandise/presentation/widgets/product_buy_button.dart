import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/merch_inquiry_form_sheet.dart';
import 'package:flutter/material.dart';

/// "Buy Now" call-to-action on Product Detail. Replaces the M1
/// disabled "Buy Now — Coming Soon" placeholder now that the inquiry
/// flow exists.
///
/// Two states:
///   - out of stock (or, for a sized product, every size out of stock)
///     → disabled, mirrors [Trek]'s "Publish this trek..."/registration-
///     closed disabled-button treatment for an unavailable action.
///   - in stock → enabled, opens [showMerchInquiryFormSheet].
///
/// A guest tapping this is handed to [AuthGuard.requireAuth], which
/// bounces to sign-in and returns here afterwards — [returnPath]
/// carries a `buy=1` flag so Product Detail can reopen the form
/// automatically once they're back, mirroring
/// TrekRegisterButton's `register=1` round trip exactly.
class ProductBuyButton extends StatelessWidget {
  const ProductBuyButton({super.key, required this.product});

  final Product product;

  Future<void> _openForm(BuildContext context) async {
    final submitted = await showMerchInquiryFormSheet(context, product: product);
    if (submitted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Thanks! We'll be in touch to arrange payment and pickup."),
        ),
      );
    }
  }

  void _guardedOpen(BuildContext context) {
    AuthGuard.requireAuth(
      context,
      returnPath: '${AppConstants.merchandiseDetailLocation(product.id)}?buy=1',
      onAuthenticated: () => _openForm(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!product.isInStock) {
      return FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.shopping_cart_outlined),
        label: const Text('Out of Stock'),
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
      );
    }

    return FilledButton.icon(
      onPressed: () => _guardedOpen(context),
      icon: const Icon(Icons.shopping_cart_outlined),
      label: const Text('Buy Now'),
      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
    );
  }
}
