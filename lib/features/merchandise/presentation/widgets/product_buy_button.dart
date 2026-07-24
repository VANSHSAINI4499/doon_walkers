import 'package:doon_walkers/core/constants/app_constants.dart';
import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/router/auth_guard.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/widgets/merch_inquiry_form_sheet.dart';
import 'package:flutter/material.dart';

/// "Buy Now" call-to-action on Product Detail — an inquiry-to-admin flow,
/// not real checkout.
///
/// Two states, unchanged across the redesign:
///   - out of stock (or every size out of stock) → disabled.
///   - in stock → opens [showMerchInquiryFormSheet].
///
/// A guest tapping this is handed to [AuthGuard.requireAuth], which bounces
/// to sign-in and returns here with a `buy=1` flag so Product Detail
/// reopens the form. Restyled onto [PremiumButton]; the stock gating and
/// the guarded round-trip are unchanged.
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
      return const PremiumButton(
        label: 'Out of Stock',
        icon: AppIcons.cart,
        onPressed: null,
        fullWidth: true,
      );
    }

    return PremiumButton(
      label: 'Buy Now',
      icon: AppIcons.cart,
      size: PremiumButtonSize.large,
      fullWidth: true,
      onPressed: () => _guardedOpen(context),
    );
  }
}
