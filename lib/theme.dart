import 'package:flutter/material.dart';

import 'services/settings.dart';

/// Paleta: branco, bege, azul-marinho e dourado discreto.
class AppColors {
  static const navy = Color(0xFF1B2A4A);
  static const navyLight = Color(0xFF2E4372);
  static const gold = Color(0xFFB8954A);
  static const beige = Color(0xFFF5EFE3);
  static const sepiaBg = Color(0xFFF1E7D0);
  static const sepiaText = Color(0xFF4E3B26);
  static const darkBg = Color(0xFF10172A);

  /// Cores de marcação dos versículos.
  static const highlights = [
    Color(0xFFFFE082),
    Color(0xFFA5D6A7),
    Color(0xFF90CAF9),
    Color(0xFFF48FB1),
    Color(0xFFCE93D8),
  ];
}

ThemeData buildTheme(ReadingTheme mode) {
  final dark = mode == ReadingTheme.dark;
  final sepia = mode == ReadingTheme.sepia;
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    brightness: dark ? Brightness.dark : Brightness.light,
  );
  final scheme = base.copyWith(
    primary: dark ? const Color(0xFFB9C7EA) : AppColors.navy,
    onPrimary: dark ? AppColors.darkBg : Colors.white,
    secondary: AppColors.gold,
    onSecondary: Colors.white,
    tertiary: AppColors.gold,
    surface: dark ? AppColors.darkBg : (sepia ? AppColors.sepiaBg : Colors.white),
    onSurface: dark ? const Color(0xFFE6E1D6) : (sepia ? AppColors.sepiaText : const Color(0xFF1E1E1E)),
    surfaceContainerLow: dark ? const Color(0xFF172036) : (sepia ? const Color(0xFFEADFC4) : AppColors.beige),
    surfaceContainer: dark ? const Color(0xFF1C2640) : (sepia ? const Color(0xFFE6D9BB) : const Color(0xFFF0E8D8)),
    surfaceContainerHighest: dark ? const Color(0xFF243052) : (sepia ? const Color(0xFFDDCDA9) : const Color(0xFFE9DFCB)),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF172036) : (sepia ? const Color(0xFFE6D9BB) : AppColors.navy),
      foregroundColor: dark || !sepia ? Colors.white : AppColors.sepiaText,
      centerTitle: false,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: AppColors.gold.withValues(alpha: 0.35),
      backgroundColor: scheme.surfaceContainerLow,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
    ),
    dividerTheme: DividerThemeData(color: AppColors.gold.withValues(alpha: 0.25)),
  );
}
