import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared styled text field used across authentication screens.
class StoraTextField extends StatefulWidget {
  final String label;
  final String hint;
  final bool obscureText;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final Key? fieldKey;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const StoraTextField({
    super.key,
    this.fieldKey,
    required this.label,
    required this.hint,
    required this.controller,
    required this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  State<StoraTextField> createState() => _StoraTextFieldState();
}

class _StoraTextFieldState extends State<StoraTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    Widget? suffix = widget.suffixIcon;
    if (widget.obscureText && suffix == null) {
      suffix = IconButton(
        icon: Icon(
          _obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: AppColors.label,
          size: 20,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.label,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: widget.fieldKey,
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: AppColors.hint, fontSize: 14),
            filled: true,
            fillColor: AppColors.fieldBackground,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: widget.prefixIcon,
            suffixIcon: suffix,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ),
      ],
    );
  }
}