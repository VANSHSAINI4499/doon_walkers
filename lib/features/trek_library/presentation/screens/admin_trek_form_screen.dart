import 'dart:typed_data';

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

  TrekDifficulty _difficulty = TrekDifficulty.moderate;
  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;
  String? _existingCoverImage;
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
    _difficulty = trek.difficulty;
    _existingCoverImage = trek.coverImage;
    _prefilled = true;
  }

  String _trimZero(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

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
        coverImageBytes: _pickedImageBytes,
        coverImageExtension: _pickedImageExtension,
        previousCoverImageUrl: _existingCoverImage,
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
        coverImageBytes: _pickedImageBytes,
        coverImageExtension: _pickedImageExtension,
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
    if (error is TrekCoverUploadException) {
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen<AsyncValue<void>>(trekAdminControllerProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_cleanError(error)),
              backgroundColor: theme.colorScheme.error,
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
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) {
          debugPrint('AdminTrekFormScreen: failed to load trek ${widget.trekId}: $error');
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Trek')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load this trek.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(trekByIdProvider(widget.trekId!)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
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
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CoverImagePicker(
                      initialImageUrl: _existingCoverImage,
                      onImagePicked: (bytes, extension) {
                        _pickedImageBytes = bytes;
                        _pickedImageExtension = extension;
                      },
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      textInputAction: TextInputAction.next,
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Please enter a title'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Please enter a description'
                          : null,
                    ),
                    const SizedBox(height: 16),

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
                    const SizedBox(height: 16),

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
                        const SizedBox(width: 12),
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
                    const SizedBox(height: 16),

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
                        const SizedBox(width: 12),
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
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _thingsToCarryController,
                      decoration: const InputDecoration(labelText: 'Things to carry'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _googleMapController,
                      decoration: const InputDecoration(
                        labelText: 'Google Maps link',
                        hintText: 'https://maps.app.goo.gl/...',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 28),

                    FilledButton(
                      onPressed: isSaving ? null : _submit,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.isEdit ? 'Save Changes' : 'Create Trek'),
                    ),
                    const SizedBox(height: 24),
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
