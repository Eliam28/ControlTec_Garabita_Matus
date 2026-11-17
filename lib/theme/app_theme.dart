import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF5F6FB);
  static const primary = Color(0xFF1D4D98);
  static const text = Color(0xFF242F3E);
  static const label = Color(0xFF4A5565);
  static const muted = Color(0xFF7D8898);
  static const hint = Color(0xFFA0A7B3);
  static const border = Color(0xFFD6DAE3);
  static const white = Colors.white;
  static const error = Color(0xFFD92D3B);
  static const warning = Color(0xFFFFEDB3);
  static const warningText = Color(0xFF3D3218);
}

abstract final class AppTheme {
  static const brand = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const title = TextStyle(
    fontSize: 30,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: AppColors.text,
  );
  static const description = TextStyle(
    fontSize: 18,
    height: 1.35,
    color: AppColors.muted,
  );
  static const label = TextStyle(
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.label,
  );
  static const requiredMark = TextStyle(color: AppColors.error);
  static const input = TextStyle(fontSize: 20, color: AppColors.text);
  static const footer = TextStyle(
    fontSize: 15,
    height: 1.3,
    color: AppColors.muted,
  );
  static const snackBarText = TextStyle(fontSize: 16, color: AppColors.white);

  static ThemeData get light {
    final textTheme = ThemeData().textTheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
        primary: AppColors.primary,
        surface: AppColors.background,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        hintStyle: input.copyWith(color: AppColors.hint),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 54),
        border: _inputBorder,
        enabledBorder: _inputBorder,
        disabledBorder: _inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          disabledForegroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 64),
          textStyle: textTheme.labelLarge!.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge!.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          minimumSize: const Size(48, 48),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
        contentTextStyle: snackBarText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        showCloseIcon: false,
      ),
    );
  }

  static final _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.border, width: 1.5),
  );
}
