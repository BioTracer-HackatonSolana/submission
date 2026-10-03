// Hallmark · designed-as-app · visual: fly.dev Workbench · IA: 4-tab
// Hallmark · tone: precise · anchor hue: cobalt
// Hallmark · pre-emit critique: P5 H5 E5 S5 R4 V4
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const cobalt = Color(0xFF3159ED);
  static const navy = Color(0xFF102D3A);
  static const lime = Color(0xFFDAF975);
  static const offWhite = Color(0xFFF5F7F4);
  static const surface = Color(0xFFF8FAF7);
  static const inkMuted = Color(0xFF52636B);
  static const rule = Color(0xFFD8E1E3);
  static const paleBlue = Color(0xFFEAF0FF);
  static const green = Color(0xFF27865C);
  static const red = Color(0xFFB83B52);
  static const amber = Color(0xFFA66C12);
  static const onAccent = Color(0xFFF5F7F4);
  static const successWash = Color(0xFFE8F5EE);
  static const errorWash = Color(0xFFF8E8EC);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.cobalt,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.cobalt,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.lime,
    onSecondary: AppColors.navy,
    surface: AppColors.surface,
    onSurface: AppColors.navy,
    error: AppColors.red,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.offWhite,
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.offWhite,
      foregroundColor: AppColors.navy,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontFamily: 'Space Grotesk',
        fontSize: 36,
        height: 1.05,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: AppColors.navy,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Space Grotesk',
        fontSize: 24,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.navy,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Space Grotesk',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: AppColors.navy),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.4,
        color: AppColors.inkMuted,
      ),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.rule),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cobalt, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.cobalt,
        foregroundColor: AppColors.onAccent,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: const BorderSide(color: AppColors.rule),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.cobalt,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.paleBlue,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.cobalt : AppColors.inkMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.cobalt : AppColors.inkMuted,
        );
      }),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.rule,
      thickness: 1,
      space: 1,
    ),
    focusColor: AppColors.cobalt,
  );
}
