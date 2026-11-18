import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/auth_messages.dart';
import 'app_routes.dart';
import 'controllers/login_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_brand.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/login_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.controller, super.key});

  final LoginController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (widget.controller.isLoading) return;
    FocusScope.of(context).unfocus();
    final succeeded = await widget.controller.login(
      _email.text,
      _password.text,
    );
    if (!mounted) return;
    if (succeeded) {
      TextInput.finishAutofillContext();
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } else {
      final error = widget.controller.errorMessage;
      if (error != null) AppSnackBar.error(context, error);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final topSpace = ((constraints.maxHeight - 650) * .8).clamp(
            32.0,
            240.0,
          );
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, topSpace, 20, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AutofillGroup(
                  child: ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppBrand(),
                        const SizedBox(height: 40),
                        const Text('Iniciar sesión', style: AppTheme.title),
                        const SizedBox(height: 8),
                        const Text(
                          'Ingresa con tu cuenta de ControlTec para ver tus servicios.',
                          style: AppTheme.description,
                        ),
                        const SizedBox(height: 34),
                        AuthTextField(
                          label: 'Correo electrónico',
                          hint: 'tecnico@empresa.com',
                          controller: _email,
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          enabled: !widget.controller.isLoading,
                        ),
                        const SizedBox(height: 22),
                        AuthTextField(
                          label: 'Contraseña',
                          hint: '••••••••',
                          controller: _password,
                          icon: Icons.lock_outline,
                          keyboardType: TextInputType.visiblePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          obscureText: _obscurePassword,
                          isPassword: true,
                          enabled: !widget.controller.isLoading,
                          onSubmitted: (_) => _login(),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => AppSnackBar.warning(
                              context,
                              AuthMessages.passwordRecovery,
                            ),
                            child: const Text('Olvidé mi contraseña'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        LoginButton(
                          isLoading: widget.controller.isLoading,
                          onPressed: _login,
                        ),
                        const SizedBox(height: 38),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Esta app es para el personal de campo. Los clientes consultan sus servicios en el portal web.',
                            textAlign: TextAlign.center,
                            style: AppTheme.footer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
