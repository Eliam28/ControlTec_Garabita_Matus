import 'package:flutter/material.dart';

import 'api/services/login_service.dart';
import 'api/app_config.dart';
import 'api/app_dependencies.dart';
import 'screens/app_routes.dart';
import 'screens/controllers/login_controller.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({
    this.config = const AppConfig.fromEnvironment(),
    this.loginService,
    super.key,
  });

  final AppConfig config;
  final LoginService? loginService;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final _dependencies = widget.loginService == null
      ? AppDependencies.fromConfig(widget.config)
      : null;
  late final _loginService = widget.loginService ?? _dependencies!.loginService;
  late final _loginController = LoginController(_loginService);

  @override
  void dispose() {
    _loginController.dispose();
    _dependencies?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ControlTec Campo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (_) => LoginScreen(controller: _loginController),
        AppRoutes.home: (_) => _loginController.session != null
            ? const HomeScreen()
            : LoginScreen(controller: _loginController),
      },
    );
  }
}
