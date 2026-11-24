import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Título de un campo. Los obligatorios llevan un asterisco rojo.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {this.required = false, super.key});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(text: ' *', style: AppTheme.requiredMark),
        ],
      ),
      style: AppTheme.fieldLabel,
    ),
  );
}
