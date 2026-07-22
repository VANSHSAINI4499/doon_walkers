import 'package:doon_walkers/core/providers/supabase_provider.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/merch_inquiry_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the "Buy Now" inquiry form as a modal sheet over Product
/// Detail. Mirrors [showRegistrationFormSheet]'s shape: the product is
/// implicit (from the screen that launched this), the user is implicit
/// (the live Supabase session), so the form only asks for what it
/// can't infer — size (if the product has any), quantity, and an
/// optional note.
///
/// This is an inquiry, not checkout — submitting creates a row an
/// admin follows up on manually. Returns true when an inquiry was
/// created, so the caller can show a confirmation.
Future<bool?> showMerchInquiryFormSheet(BuildContext context, {required Product product}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _MerchInquiryFormSheet(product: product),
  );
}

class _MerchInquiryFormSheet extends ConsumerStatefulWidget {
  const _MerchInquiryFormSheet({required this.product});

  final Product product;

  @override
  ConsumerState<_MerchInquiryFormSheet> createState() => _MerchInquiryFormSheetState();
}

class _MerchInquiryFormSheetState extends ConsumerState<_MerchInquiryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _noteController = TextEditingController();
  final _phoneController = TextEditingController();

  ProductVariant? _selectedVariant;

  /// Set once, on submit — a missing size selection is only worth
  /// complaining about after the member's actually tried to submit,
  /// same "no live-validate-while-typing noise" convention the
  /// registration form's gender dropdown uses.
  bool _showSizeRequiredError = false;

  List<ProductVariant> get _inStockVariants =>
      widget.product.variants.where((v) => v.isInStock).toList();

  @override
  void initState() {
    super.initState();
    final variants = _inStockVariants;
    if (variants.length == 1) _selectedVariant = variants.first;

    // Pre-fill from the account's phone if set — still editable, since
    // the member may want a different number reached for this specific
    // order (see MerchInquiry.phoneNumber's doc).
    _phoneController.text = ref.read(currentUserProvider).valueOrNull?.phone ?? '';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.product.hasVariants && _selectedVariant == null) {
      setState(() => _showSizeRequiredError = true);
      return;
    }

    final note = _noteController.text.trim();
    final created = await ref.read(merchInquiryControllerProvider.notifier).submitInquiry(
          productId: widget.product.id,
          variantId: _selectedVariant?.id,
          quantity: int.parse(_quantityController.text.trim()),
          note: note.isEmpty ? null : note,
          phoneNumber: _phoneController.text.trim(),
        );

    if (!mounted || created == null) return;
    Navigator.of(context).pop(true);
  }

  String _errorMessage(Object error) {
    debugPrint('MerchInquiryFormSheet: submission failed: $error');
    return 'Could not send your inquiry. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSaving = ref.watch(merchInquiryControllerProvider).isLoading;

    ref.listen<AsyncValue<void>>(merchInquiryControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage(error)),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        },
      );
    });

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Inquire about this product',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.product.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This sends your interest to our team — we'll reach out to arrange "
                'payment and pickup/delivery. This is not a checkout.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              if (widget.product.hasVariants) ...[
                DropdownButtonFormField<ProductVariant>(
                  value: _selectedVariant,
                  decoration: InputDecoration(
                    labelText: 'Size',
                    errorText: _showSizeRequiredError ? 'Please select a size' : null,
                  ),
                  items: _inStockVariants
                      .map((v) => DropdownMenuItem(value: v, child: Text(v.size)))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedVariant = value;
                    _showSizeRequiredError = false;
                  }),
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact phone number',
                  hintText: "We'll call or text this number about your order",
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a phone number'
                    : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Please enter a quantity';
                  final qty = int.tryParse(text);
                  if (qty == null || qty <= 0) return 'Enter a quantity of at least 1';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: "Anything we should know — e.g. when you'd like to collect it",
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: isSaving ? null : _submit,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Inquiry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
