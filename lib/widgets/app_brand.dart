import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBrand extends StatelessWidget {
  const AppBrand({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.bug_report_outlined,
          color: AppColors.white,
          size: 29,
        ),
      ),
      const SizedBox(width: 13),
      const Expanded(child: Text('ControlTec Campo', style: AppTheme.brand)),
    ],
  );
}
