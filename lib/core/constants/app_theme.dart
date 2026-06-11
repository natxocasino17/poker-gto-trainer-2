import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.gold,
        surface: AppColors.surface,
        error: AppColors.actionFold,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardTheme(
        color: AppColors.card,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        bodySmall: TextStyle(color: AppColors.textMuted, fontSize: 11),
        labelLarge: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
    );
  }
}
