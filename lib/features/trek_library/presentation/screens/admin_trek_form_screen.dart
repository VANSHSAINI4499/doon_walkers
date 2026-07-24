import 'dart:typed_data';

import 'package:doon_walkers/core/design_system.dart';
import 'package:doon_walkers/core/widgets/admin_form.dart';
import 'package:doon_walkers/features/trek_library/domain/entities/trek.dart';
import 'package:doon_walkers/features/trek_library/presentation/providers/trek_providers.dart';
import 'package:doon_walkers/features/trek_library/presentation/widgets/cover_image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shared Add/Edit trek form — [trekId] null means "Add Trek" (empty
/// form, calls createTrek); non-null means "Edit Trek" (pre-filled from
/// [trekByIdProvider], calls updateTrek). One form, two modes, per the
/// Phase 4 brief.
class AdminTrekFormScreen extends ConsumerStatefulWidget {
  const AdminTrekFormScreen({super.key, this.trekId});

  final String? trekId;

  bool get isEdit => trekId != null;

  @override
  ConsumerState<AdminTrekFormScreen> createState() => _AdminTrekFormScreenState();
}

class _AdminTrekFormScreenState extends ConsumerState<AdminTrekFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _altitudeController = TextEditingController();
  final _bestSeasonController = TextEditingController();
  final _thingsToCarryController = TextEditingController();
  final _googleMapController = TextEditingController();
  final _feeController = TextEditingController(text: '0');

  TrekDifficulty _difficulty = TrekDifficulty.moderate;
  DateTime? _trekDate;
  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;
  String? _existingCoverImage;

  /// Tracked separately from `_feeController.text` (rather than parsed
  /// only at submit time) so the QR code picker below can appear/
  /// disappear live as the admin types, instead of only after saving.
  double _registrationFee = 0;
  Uint8List? _pickedQrBytes;
  String? _pickedQrExtension;
  String? _existingQrCode;

  bool _prefilled = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _altitudeController.dispose();
    _bestSeasonController.dispose();
    _thingsToCarryController.dispose();
    _googleMapController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  void _prefillFrom(Trek trek) {
    if (_prefilled) return;
    _titleController.text = trek.title;
    _descriptionController.text = trek.description;
    _distanceController.text = trek.distanceKm == null ? '' : _trimZero(trek.distanceKm!);
    _durationController.text = trek.durationDays?.toString() ?? '';
    _altitudeController.text = trek.altitudeM?.toString() ?? '';
    _bestSeasonController.text = trek.bestSeason ?? '';
    _thingsToCarryController.text = trek.thingsToCarry ?? '';
    _googleMapController.text = trek.googleMapLink ?? '';
    _feeController.text = _trimZero(trek.registrationFee);
    _difficulty = trek.difficulty;
    _trekDate = trek.trekDate;
    _registrationFee = trek.registrationFee;
    _existingCoverImage = trek.coverImage;
    _existingQrCode = trek.paymentQrCode;
    _prefilled = true;
  }

  String _trimZero(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _pickTrekDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _trekDate ?? now,
      // Editing an existing trek scheduled in the past (e.g. fixing a
      // typo after the fact) shouldn't be blocked by "must be in the
      // future" — only the lower bound is a sane calendar floor.
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _trekDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(trekAdminControllerProvider.notifier);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final distanceKm = _parseOrNullDouble(_distanceController.text);
    final durationDays = _parseOrNullInt(_durationController.text);
    final altitudeM = _parseOrNullInt(_altitudeController.text);
    final bestSeason = _emptyToNull(_bestSeasonController.text);
    final thingsToCarry = _emptyToNull(_thingsToCarryController.text);
    final googleMapLink = _emptyToNull(_googleMapController.text);

    if (widget.isEdit) {
      final success = await controller.updateTrek(
        id: widget.trekId!,
        title: title,
        description: description,
        difficulty: _difficulty,
        distanceKm: distanceKm,
        durationDays: durationDays,
        altitudeM: altitudeM,
        bestSeason: bestSeason,
        thingsToCarry: thingsToCarry,
        googleMapLink: googleMapLink,
        trekDate: _trekDate,
        registrationFee: _registrationFee,
        coverImageBytes: _pickedImageBytes,
        coverImageExtension: _pickedImageExtension,
        previousCoverImageUrl: _existingCoverImage,
        // Only sent when the fee is actually > 0 — if an admin drops the
        // fee to 0 after having picked a QR code, don't upload it.
        qrCodeBytes: _registrationFee > 0 ? _pickedQrBytes : null,
        qrCodeExtension: _registrationFee > 0 ? _pickedQrExtension : null,
        previousQrCodeUrl: _existingQrCode,
      );
      if (!mounted || !success) return;
      // publishedTreksProvider/adminAllTreksProvider are one-shot fetches
      // (not live streams — see their docs), so they need an explicit
      // invalidate to pick up this edit.
      ref.invalidate(publishedTreksProvider);
      ref.invalidate(adminAllTreksProvider);
      ref.invalidate(trekByIdProvider(widget.trekId!));
      context.pop();
    } else {
      final created = await controller.createTrek(
        title: title,
        description: description,
        difficulty: _difficulty,
        distanceKm: distanceKm,
        durationDays: durationDays,
        altitudeM: altitudeM,
        bestSeason: bestSeason,
        thingsToCarry: thingsToCarry,
        googleMapLink: googleMapLink,
        trekDate: _trekDate,
        registrationFee: _registrationFee,
        coverImageBytes: _pickedImageBytes,
        coverImageExtension: _pickedImageExtension,
        qrCodeBytes: _registrationFee > 0 ? _pickedQrBytes : null,
        qrCodeExtension: _registrationFee > 0 ? _pickedQrExtension : null,
      );
      if (!mounted || created == null) return;
      ref.invalidate(publishedTreksProvider);
      ref.invalidate(adminAllTreksProvider);
      context.pop();
    }
  }

  double? _parseOrNullDouble(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim());
  int? _parseOrNullInt(String text) => text.trim().isEmpty ? null : int.tryParse(text.trim());
  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  String _cleanError(Object error) {
    debugPrint('AdminTrekFormScreen: mutation failed: $error');
    if (error is TrekImageUploadException) {
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(trekAdminControllerProvider, (previous, next) {
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
      final trekAsync = ref.watch(trekByIdProvider(widget.trekId!));
      return trekAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Edit Trek')),
          body: const AdminFormLoadingSkeleton(showImage: true),
        ),
        error: (error, stack) {
          debugPrint('AdminTrekFormScreen: failed to load trek ${widget.trekId}: $error');
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Trek')),
            body: AdminFormErrorState(
              message: 'Could not load this trek.',
              onRetry: () => ref.invalidate(trekByIdProvider(widget.trekId!)),
            ),
          );
        },
        data: (trek) {
          if (trek == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Edit Trek')),
              body: const Center(child: Text('Trek not found.')),
            );
          }
          _prefillFrom(trek);
          return _buildForm(context, title: 'Edit Trek');
        },
      );
    }

    return _buildForm(context, title: 'Add Trek');
  }

  Widget _buildForm(BuildContext context, {required String title}) {
    final isSaving = ref.watch(trekAdminControllerProvider).isLoading;

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
                              const AdminFormSectionLabel('Cover Image'),
                              const SizedBox(height: AppSpacing.md),
                              CoverImagePicker(
                                initialImageUrl: _existingCoverImage,
                                onImagePicked: (bytes, extension) {
                                  _pickedImageBytes = bytes;
                                  _pickedImageExtension = extension;
                                },
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              const Divider(),
                              const SizedBox(height: AppSpacing.xl),

                              const AdminFormSectionLabel('Details'),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _titleController,
                                decoration: const InputDecoration(labelText: 'Title'),
                                textInputAction: TextInputAction.next,
                                validator: (value) => (value == null || value.trim().isEmpty)
                                    ? 'Please enter a title'
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              TextFormField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(labelText: 'Description'),
                                maxLines: 4,
                                textInputAction: TextInputAction.newline,
                                validator: (value) => (value == null || value.trim().isEmpty)
                                    ? 'Please enter a description'
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              DropdownButtonFormField<TrekDifficulty>(
                                value: _difficulty,
                                decoration: const InputDecoration(labelText: 'Difficulty'),
                                items: TrekDifficulty.values
                                    .map((d) => DropdownMenuItem(value: d, child: Text(d.label)))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) setState(() => _difficulty = value);
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _distanceController,
                                      decoration: const InputDecoration(labelText: 'Distance (km)'),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      validator: (value) => (value != null &&
                                              value.trim().isNotEmpty &&
                                              double.tryParse(value.trim()) == null)
                                          ? 'Invalid number'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _durationController,
                                      decoration: const InputDecoration(labelText: 'Duration (days)'),
                                      keyboardType: TextInputType.number,
                                      validator: (value) => (value != null &&
                                              value.trim().isNotEmpty &&
                                              int.tryParse(value.trim()) == null)
                                          ? 'Invalid number'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              InkWell(
                                onTap: _pickTrekDate,
                                borderRadius: BorderRadius.circular(AppRadius.button),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Trek date (optional)',
                                    suffixIcon: _trekDate == null
                                        ? const AppIcon(AppIcons.calendar, size: 20)
                                        : IconButton(
                                            icon: const AppIcon(AppIcons.close, size: 20),
                                            tooltip: 'Clear date',
                                            onPressed: () => setState(() => _trekDate = null),
                                          ),
                                  ),
                                  child: Text(
                                    _trekDate == null ? 'Not scheduled yet' : _formatDate(_trekDate!),
                                    style: AppTextStyles.bodyLarge,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _altitudeController,
                                      decoration: const InputDecoration(labelText: 'Max altitude (m)'),
                                      keyboardType: TextInputType.number,
                                      validator: (value) => (value != null &&
                                              value.trim().isNotEmpty &&
                                              int.tryParse(value.trim()) == null)
                                          ? 'Invalid number'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _bestSeasonController,
                                      decoration: const InputDecoration(
                                        labelText: 'Best season',
                                        hintText: 'e.g. Oct – Feb',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              TextFormField(
                                controller: _thingsToCarryController,
                                decoration: const InputDecoration(labelText: 'Things to carry'),
                                maxLines: 3,
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              TextFormField(
                                controller: _googleMapController,
                                decoration: const InputDecoration(
                                  labelText: 'Google Maps link',
                                  hintText: 'https://maps.app.goo.gl/...',
                                ),
                                keyboardType: TextInputType.url,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              const Divider(),
                              const SizedBox(height: AppSpacing.xl),

                              const AdminFormSectionLabel(
                                'Registration',
                                subtitle: 'Set a fee to require a payment QR code for members.',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _feeController,
                                decoration: const InputDecoration(
                                  labelText: 'Registration fee (₹)',
                                  hintText: '0 = free, no payment step for members',
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) return null; // treated as 0
                                  final parsed = double.tryParse(text);
                                  if (parsed == null) return 'Invalid number';
                                  if (parsed < 0) return 'Fee can\'t be negative';
                                  return null;
                                },
                                onChanged: (value) {
                                  setState(() => _registrationFee = double.tryParse(value.trim()) ?? 0);
                                },
                              ),

                              // Only offered once a fee is actually set — a
                              // free trek has no payment step, so there's
                              // nothing for a QR code to be attached to.
                              if (_registrationFee > 0) ...[
                                const SizedBox(height: AppSpacing.lg),
                                CoverImagePicker(
                                  initialImageUrl: _existingQrCode,
                                  hintText: 'Tap to add a payment QR code',
                                  onImagePicked: (bytes, extension) {
                                    _pickedQrBytes = bytes;
                                    _pickedQrExtension = extension;
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    AdminFormActions(
                      isSaving: isSaving,
                      saveLabel: widget.isEdit ? 'Save Changes' : 'Create Trek',
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
