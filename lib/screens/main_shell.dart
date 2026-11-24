import 'package:flutter/material.dart';

import '../api/app_dependencies.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import 'controllers/login_controller.dart';
import 'controllers/profile_controller.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    required this.authentication,
    required this.dependencies,
    super.key,
  });

  final LoginController authentication;
  final AppDependencies dependencies;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  ProfileController? _profile;
  final List<Widget?> _pages = [null, null, null];

  void _select(int index) {
    if (widget.authentication.isSigningOut || index == _index) return;
    setState(() {
      _index = index;
      if (index == 1) _pages[1] ??= const ReportsScreen();
      if (index == 2 && _pages[2] == null) {
        _profile = ProfileController(
          authentication: widget.authentication,
          loginService: widget.dependencies.loginService,
          profileService: widget.dependencies.profileService!,
          myDayService: widget.dependencies.myDayService,
          daySnapshot: widget.dependencies.daySnapshot!,
        );
        _pages[2] = ProfileScreen(controller: _profile!);
      }
    });
  }

  @override
  void dispose() {
    _profile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.authentication.session;
    if (session == null) return const SizedBox.shrink();
    _pages[0] = HomeScreen(
      key: const ValueKey('existing-my-day'),
      myDayService: widget.dependencies.myDayService,
      technicianName: session.technician.name,
    );
    return PopScope(
      canPop: !widget.authentication.isSigningOut,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: _pages
              .map((page) => page ?? const SizedBox.shrink())
              .toList(),
        ),
        bottomNavigationBar: AppBottomNavigationBar(
          currentIndex: _index,
          onTap: _select,
          enabled: !widget.authentication.isSigningOut,
        ),
      ),
    );
  }
}
