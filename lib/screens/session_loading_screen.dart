import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_brand.dart';

class SessionLoadingScreen extends StatelessWidget {
  const SessionLoadingScreen({this.error, required this.onRetry, super.key});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppBrand(),
                const SizedBox(height: 32),
                if (error == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Verificando tu sesión…', style: AppTheme.body),
                ] else ...[
                  Text(
                    error!,
                    style: AppTheme.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
