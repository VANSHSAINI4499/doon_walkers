import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/admin_form.dart';
import 'package:doon_walkers/features/merchandise/domain/entities/product.dart';
import 'package:doon_walkers/features/merchandise/presentation/providers/product_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One local, editable row in the Sizes section — owns its own
/// controllers so each row's text fields keep their own cursor/focus
/// state independently of the others as rows are added/removed.
class _VariantRow {
  _VariantRow({String size = '', int stock = 0})
      : sizeController = TextEditingController(text: size),
        stockController = TextEditingController(text: stock.toString());

  final TextEditingController sizeController;
  final TextEditingController stockController;

  void dispose() {
    sizeController.dispose();
    stockController.dispose();
  }
}

/// Shared Add/Edit product form — [productId] null means "Add Product"
/// (empty form, calls createProduct); non-null means "Edit Product"
/// (pre-filled from [productByIdProvider], calls updateProduct). One
/// form, two modes, mirrors AdminTrekFormScreen.
///
/// No image picker and no active/inactive toggle here — photos are
/// managed on the product's own detail page (ProductImagesSection,
/// same pattern as a trek's gallery) and active/inactive is toggled via
/// ProductAdminActions' menu (mirrors is_published never being a form
/// field either), not baked into this form.
class AdminProductFormScreen extends ConsumerStatefulWidget {
  const AdminProductFormScreen({super.key, this.productId});

  final String? productId;

  bool get isEdit => productId != null;

  @override
  ConsumerState<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends ConsumerState<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');

  ProductCategory _category = ProductCategory.other;
  final List<_VariantRow> _variantRows = [];
  List<ProductVariant> _existingVariants = const [];

  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    for (final row in _variantRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _prefillFrom(Product product) {
    if (_prefilled) return;
    _nameController.text = product.name;
    _descriptionController.text = product.description;
    _priceController.text = _trimZero(product.price);
    _stockController.text = product.stockQuantity.toString();
    _category = product.category;
    _existingVariants = product.variants;
    for (final variant in product.variants) {
      _variantRows.add(_VariantRow(size: variant.size, stock: variant.stockQuantity));
    }
    _prefilled = true;
  }

  String _trimZero(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  void _addVariantRow() => setState(() => _variantRows.add(_VariantRow()));

  void _removeVariantRow(int index) {
    setState(() => _variantRows.removeAt(index).dispose());
  }

  /// Trims and drops any row left with an empty size — an admin adding
  /// a row and then not filling it in shouldn't block or corrupt
  /// submission, it's just discarded.
  List<(String, int)> _collectVariants() {
    final seen = <String>{};
    final result = <(String, int)>[];
    for (final row in _variantRows) {
      final size = row.sizeController.text.trim();
      if (size.isEmpty || !seen.add(size)) continue;
      final stock = int.tryParse(row.stockController.text.trim()) ?? 0;
      result.add((size, stock));
    }
    return result;
  }

  /// Client-side duplicate check (case-sensitive, matching the DB's
  /// `UNIQUE (product_id, size)` constraint exactly) — catches the
  /// mistake before submit rather than surfacing a raw Postgres
  /// unique-violation error.
  String? _validateVariantRows() {
    final seen = <String>{};
    for (final row in _variantRows) {
      final size = row.sizeController.text.trim();
      if (size.isEmpty) continue;
      if (!seen.add(size)) return 'Size "$size" is listed more than once.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final duplicateError = _validateVariantRows();
    if (duplicateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(duplicateError)),
      );
      return;
    }

    final controller = ref.read(productAdminControllerProvider.notifier);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final stockQuantity = int.tryParse(_stockController.text.trim()) ?? 0;
    final variants = _collectVariants();

    if (widget.isEdit) {
      final success = await controller.updateProduct(
        id: widget.productId!,
        name: name,
        description: description,
        price: price,
        category: _category,
        stockQuantity: stockQuantity,
        existing: _existingVariants,
        variants: variants,
      );
      if (!mounted || !success) return;
      ref.invalidate(activeProductsProvider);
      ref.invalidate(adminAllProductsProvider);
      ref.invalidate(productByIdProvider(widget.productId!));
      context.pop();
    } else {
      final created = await controller.createProduct(
        name: name,
        description: description,
        price: price,
        category: _category,
        stockQuantity: stockQuantity,
        variants: variants,
      );
      if (!mounted || created == null) return;
      ref.invalidate(activeProductsProvider);
      ref.invalidate(adminAllProductsProvider);
      context.pop();
    }
  }

  String _cleanError(Object error) {
    debugPrint('AdminProductFormScreen: mutation failed: $error');
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(productAdminControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_cleanError(error)),
              backgroundColor: AppColors.danger,
            ),
          );
        },
      );
    });

    if (widget.isEdit) {
      final productAsync = ref.watch(productByIdProvider(widget.productId!));
      return productAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Edit Product')),
          body: const AdminFormLoadingSkeleton(),
        ),
        error: (error, stack) {
          debugPrint('AdminProductFormScreen: failed to load product ${widget.productId}: $error');
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Product')),
            body: AdminFormErrorState(
              message: 'Could not load this product.',
              onRetry: () => ref.invalidate(productByIdProvider(widget.productId!)),
            ),
          );
        },
        data: (product) {
          if (product == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Edit Product')),
              body: const Center(child: Text('Product not found.')),
            );
          }
          _prefillFrom(product);
          return _buildForm(context, title: 'Edit Product');
        },
      );
    }

    return _buildForm(context, title: 'Add Product');
  }

  Widget _buildForm(BuildContext context, {required String title}) {
    final isSaving = ref.watch(productAdminControllerProvider).isLoading;
    final hasSizes = _variantRows.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassCard(
                      child: AbsorbPointer(
                        absorbing: isSaving,
                        child: Opacity(
                          opacity: isSaving ? 0.5 : 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const AdminFormSectionLabel('Details'),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(labelText: 'Name'),
                                textInputAction: TextInputAction.next,
                                validator: (value) => (value == null || value.trim().isEmpty)
                                    ? 'Please enter a name'
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              TextFormField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(labelText: 'Description'),
                                maxLines: 4,
                                textInputAction: TextInputAction.newline,
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              DropdownButtonFormField<ProductCategory>(
                                value: _category,
                                decoration: const InputDecoration(labelText: 'Category'),
                                items: ProductCategory.values
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) setState(() => _category = value);
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              TextFormField(
                                controller: _priceController,
                                decoration: const InputDecoration(labelText: 'Price (₹)'),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) return 'Please enter a price';
                                  final parsed = double.tryParse(text);
                                  if (parsed == null) return 'Invalid number';
                                  if (parsed < 0) return 'Price can\'t be negative';
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              const Divider(),
                              const SizedBox(height: AppSpacing.xl),

                              // Only shown/used when there are no size rows
                              // below — once a product has sizes, stock is
                              // tracked per size instead (see
                              // Product.isInStock's doc).
                              if (!hasSizes) ...[
                                const AdminFormSectionLabel('Stock'),
                                const SizedBox(height: AppSpacing.md),
                                TextFormField(
                                  controller: _stockController,
                                  decoration: const InputDecoration(
                                    labelText: 'Stock',
                                    hintText: 'Leave sizes empty below if this product has no sizes',
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    if (text.isEmpty) return null; // treated as 0
                                    if (int.tryParse(text) == null) return 'Invalid number';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                const Divider(),
                                const SizedBox(height: AppSpacing.xl),
                              ],

                              Row(
                                children: [
                                  const Expanded(child: AdminFormSectionLabel('Sizes (optional)')),
                                  TextButton.icon(
                                    onPressed: _addVariantRow,
                                    icon: const AppIcon(AppIcons.add, size: 18),
                                    label: const Text('Add Size'),
                                  ),
                                ],
                              ),
                              if (hasSizes) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Stock is tracked per size below; the flat Stock field above is ignored.',
                                  style: AppTextStyles.secondary(AppTextStyles.bodySmall),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              for (var i = 0; i < _variantRows.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          controller: _variantRows[i].sizeController,
                                          decoration: const InputDecoration(labelText: 'Size'),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: _variantRows[i].stockController,
                                          decoration: const InputDecoration(labelText: 'Stock'),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _removeVariantRow(i),
                                        icon: const AppIcon(AppIcons.close, size: 20),
                                        tooltip: 'Remove size',
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    AdminFormActions(
                      isSaving: isSaving,
                      saveLabel: widget.isEdit ? 'Save Changes' : 'Create Product',
                      onSave: _submit,
                      onCancel: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
