import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.readOnly = false,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool readOnly;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        suffixIcon: readOnly
            ? const Icon(Icons.lock_outline_rounded, size: 18)
            : null,
      ),
    );
  }
}
