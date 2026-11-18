import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LoginButton extends StatelessWidget {
  const LoginButton({
    required this.isLoading,
    required this.onPressed,
    super.key,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: isLoading ? null : onPressed,
    child: isLoading
        ? Semantics(
            label: 'Iniciando sesión',
            child: const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.white,
              ),
            ),
          )
        : const Text('Iniciar sesión'),
  );
}
