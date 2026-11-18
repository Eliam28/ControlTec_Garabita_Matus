import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

abstract final class AppSnackBar {
  static const duration = Duration(seconds: 3);

  static void error(BuildContext context, String message) =>
      _show(context, message, warning: false);

  static void warning(BuildContext context, String message) =>
      _show(context, message, warning: true);

  static void _show(
    BuildContext context,
    String message, {
    required bool warning,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTheme.snackBarText.copyWith(
            color: warning ? AppColors.warningText : AppColors.white,
          ),
        ),
        backgroundColor: warning ? AppColors.warning : AppColors.error,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
