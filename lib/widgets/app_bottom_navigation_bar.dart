import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: enabled ? onTap : null,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.muted,
      selectedFontSize: 13,
      unselectedFontSize: 13,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month_outlined),
          label: 'Mi día',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_outlined),
          label: 'Reportes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_circle_outlined),
          label: 'Perfil',
        ),
      ],
    ),
  );
}
