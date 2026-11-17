import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    required this.autofillHints,
    this.obscureText = false,
    this.isPassword = false,
    this.enabled = true,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final Iterable<String> autofillHints;
  final bool obscureText;
  final bool isPassword;
  final bool enabled;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          text: label,
          children: const [TextSpan(text: ' *', style: AppTheme.requiredMark)],
        ),
        style: AppTheme.label,
      ),
      const SizedBox(height: 9),
      Semantics(
        label: label,
        child: TextField(
          controller: controller,
          enabled: enabled,
          style: AppTheme.input,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          obscureText: obscureText,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: !isPassword,
          onSubmitted: onSubmitted,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 24),
            suffixIcon: suffixIcon,
          ),
        ),
      ),
    ],
  );
}
