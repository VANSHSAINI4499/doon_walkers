import 'package:doon_walkers/core/motion/app_motion.dart';
import 'package:doon_walkers/core/theme/app_colors.dart';
import 'package:doon_walkers/core/theme/app_dimens.dart';
import 'package:doon_walkers/core/theme/app_shadows.dart';
import 'package:doon_walkers/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A row of single-digit boxes for entering a numeric OTP — Material 3
/// styled, matching DoonWalkers' rounded-box input language rather than
/// a plain [TextField]. Built for phone verification (Version 2) but
/// generic over [length] so it's reusable for a future email OTP flow.
///
/// Handles, with no external package:
///  - auto-advance to the next box as each digit is typed
///  - backspace on an empty box moving back to the previous one and
///    clearing it
///  - pasting (or SMS-autofilling) the full code into any single box,
///    which gets distributed across the remaining boxes from there
///  - Android SMS autofill (via [AutofillHints.oneTimeCode]) — actual
///    autofill still depends on the SMS content matching what Android's
///    autofill service recognizes, which is outside this widget's
///    control, but the code itself lands through the same paste-style
///    distribution path either way.
///
/// ```dart
/// OTPInput(
///   key: _otpInputKey, // GlobalKey<OTPInputState> — lets a parent call .clear()
///   length: 4,
///   enabled: !isLoading,
///   errorText: _otpError,
///   onCompleted: (code) => _verify(code),
/// )
/// ```
class OTPInput extends StatefulWidget {
  const OTPInput({
    super.key,
    required this.length,
    required this.onCompleted,
    this.onChanged,
    this.enabled = true,
    this.errorText,
    this.autofocus = true,
  });

  /// Number of digit boxes — 4 for MSG91's OTP widget, kept generic for
  /// other providers/flows.
  final int length;

  /// Fires every time all [length] boxes are filled — not just once, so
  /// re-entering a code after [OTPInputState.clear] fires it again too.
  final ValueChanged<String> onCompleted;

  /// Fires on every keystroke with the current (possibly incomplete)
  /// code — typically used to clear a stale [errorText] the moment the
  /// user starts editing again.
  final ValueChanged<String>? onChanged;

  final bool enabled;

  /// Shown BELOW the row of boxes, not inside any one of them — once the
  /// input is split across separate boxes there's no single field left
  /// to anchor an inline [InputDecoration.errorText] to.
  final String? errorText;

  final bool autofocus;

  @override
  State<OTPInput> createState() => OTPInputState();
}

class OTPInputState extends State<OTPInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get code => _controllers.map((c) => c.text).join();

  /// Clears every box and returns focus to the first — call after a
  /// failed verification so the user can retype without manually
  /// clearing each box themselves.
  void clear() {
    for (final controller in _controllers) {
      controller.clear();
    }
    setState(() {});
    if (widget.enabled) _focusNodes.first.requestFocus();
    widget.onChanged?.call('');
  }

  void _handleChanged(int index, String value) {
    if (value.length > 1) {
      // A paste (or SMS autofill) landed more than one character in a
      // single box — distribute digits across this box and the ones
      // after it instead of treating it as one keystroke.
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      var cursor = index;
      for (var i = 0; i < digits.length && cursor < widget.length; i++) {
        _controllers[cursor].text = digits[i];
        cursor++;
      }
      if (cursor >= widget.length) {
        _focusNodes[widget.length - 1].unfocus();
      } else {
        _focusNodes[cursor].requestFocus();
      }
    } else if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    setState(() {});
    final current = code;
    widget.onChanged?.call(current);
    if (current.length == widget.length) {
      widget.onCompleted(current);
    }
  }

  void _handleBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      setState(() {});
      widget.onChanged?.call(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Verification code, ${widget.length} digits',
          child: AutofillGroup(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  _OTPDigitBox(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    enabled: widget.enabled,
                    hasError: widget.errorText != null,
                    autofocus: widget.autofocus && i == 0,
                    semanticLabel: 'Digit ${i + 1} of ${widget.length}',
                    onChanged: (value) => _handleChanged(i, value),
                    onBackspace: () => _handleBackspace(i),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.errorText!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

class _OTPDigitBox extends StatefulWidget {
  const _OTPDigitBox({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.autofocus,
    required this.semanticLabel,
    required this.onChanged,
    required this.onBackspace,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final bool autofocus;
  final String semanticLabel;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  @override
  State<_OTPDigitBox> createState() => _OTPDigitBoxState();
}

class _OTPDigitBoxState extends State<_OTPDigitBox> {
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  Color get _borderColor {
    if (widget.hasError) return AppColors.danger;
    if (_focused) return AppColors.primary;
    if (_hovered) return AppColors.textSecondary;
    return AppColors.glassBorder;
  }

  @override
  Widget build(BuildContext context) {
    final box = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      width: 52,
      height: 58,
      decoration: BoxDecoration(
        color: _focused ? AppColors.cardHigh : AppColors.card,
        borderRadius: AppRadius.all(AppRadius.sm),
        border: Border.all(color: _borderColor, width: _focused || widget.hasError ? 2 : 1),
        boxShadow: _focused && !widget.hasError
            ? AppShadows.glow(AppColors.primary, opacity: 0.3, radius: 14)
            : widget.hasError
                ? AppShadows.glow(AppColors.danger, opacity: 0.25, radius: 14)
                : null,
      ),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              widget.controller.text.isEmpty) {
            widget.onBackspace();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTextStyles.headlineSmall.copyWith(letterSpacing: 0),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );

    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: widget.enabled ? 1 : 0.5,
          child: box,
        ),
      ),
    );
  }
}
