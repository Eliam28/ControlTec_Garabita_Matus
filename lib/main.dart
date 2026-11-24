import 'dart:async';

import 'package:flutter/material.dart';

import 'api/services/login_service.dart';
import 'api/app_config.dart';
import 'api/app_dependencies.dart';
import 'screens/app_routes.dart';
import 'screens/controllers/login_controller.dart';
import 'screens/main_shell.dart';
import 'screens/login_screen.dart';
import 'screens/session_loading_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({
    this.config = const AppConfig.fromEnvironment(),
    this.loginService,
    this.dependencies,
    super.key,
  });

  final AppConfig config;
  final LoginService? loginService;
  final AppDependencies? dependencies;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  late final _dependencies =
      widget.dependencies ??
      (widget.loginService == null
          ? AppDependencies.fromConfig(widget.config)
          : AppDependencies.fromLoginService(widget.loginService!));
  late final _loginController = LoginController(_dependencies.loginService);
  GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  String? _account;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loginController.addListener(_authChanged);
    unawaited(_loginController.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loginController.validateActiveSession());
    }
  }

  void _authChanged() {
    if (!mounted) return;
    final user = _loginController.session?.technician;
    final account = user == null ? null : user.id ?? user.email ?? user.name;
    if (_account != account) {
      if (_account != null) _dependencies.clearSessionData();
      _account = account;
      _navigator = GlobalKey<NavigatorState>();
    }
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loginController.removeListener(_authChanged);
    _loginController.dispose();
    if (widget.dependencies == null) _dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ControlTec Campo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: _navigator,
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (_) => ListenableBuilder(
          listenable: _loginController,
          builder: (_, _) => _sessionGate(),
        ),
        AppRoutes.home: (_) => ListenableBuilder(
          listenable: _loginController,
          builder: (_, _) => _sessionGate(),
        ),
      },
    );
  }

  Widget _sessionGate() {
    if (_loginController.isCheckingSession ||
        _loginController.recoveryError != null) {
      return SessionLoadingScreen(
        error: _loginController.recoveryError,
        onRetry: () => unawaited(_loginController.initialize()),
      );
    }
    return _loginController.session == null
        ? LoginScreen(controller: _loginController)
        : MainShell(
            authentication: _loginController,
            dependencies: _dependencies,
          );
  }
}
