import 'package:doon_walkers/core/design_system.dart';
import 'package:flutter/material.dart';

/// Reusable styled form field for authentication screens.
///
/// The glass-card look (fill, border, focus/error states) comes entirely
/// from [AppTheme.dark]'s `inputDecorationTheme` — this widget only wires
/// up behaviour (obscure-text toggle, validation) and draws its icons
/// through [AppIcon] so they stay on the filled Material Symbols set
/// rather than the legacy `Icons.*` font.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.hint,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppIcon(widget.prefixIcon, size: 20, color: AppColors.textSecondary),
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: AppIcon(
                  _obscureText ? AppIcons.hidden : AppIcons.visible,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : null,
      ),
    );
  }
}
