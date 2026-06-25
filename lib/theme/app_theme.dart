import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Colour palette ────────────────────────────────────────────────────────────

abstract final class AppColors {
  // Backgrounds
  static const Color background  = Color(0xFF0B0F1E);
  static const Color surface     = Color(0xFF141829);
  static const Color card        = Color(0xFF1C2136);
  static const Color cardLight   = Color(0xFF252B45);

  // Brand
  static const Color accent      = Color(0xFF6C63FF);
  static const Color accentDim   = Color(0xFF4D46CC);

  // Semantic
  static const Color positive    = Color(0xFF4ADE80);
  static const Color negative    = Color(0xFFFC8181);
  static const Color warning     = Color(0xFFFBBF24);

  // Text
  static const Color textPrimary   = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF475569);
  static const Color divider       = Color(0xFF1E293B);

  // Income category colours
  static Color income(String name) {
    switch (name.toLowerCase()) {
      case 'salary':            return const Color(0xFF4ADE80);
      case 'freelance':         return const Color(0xFF60A5FA);
      case 'business':          return const Color(0xFFFBBF24);
      case 'investment return': return const Color(0xFFA78BFA);
      case 'bonus':             return const Color(0xFF2DD4BF);
      case 'gift':              return const Color(0xFFF472B6);
      case 'others':            return const Color(0xFF94A3B8);
      default:                  return const Color(0xFF4ADE80);
    }
  }

  // Expense category colours
  static Color category(String name) {
    switch (name.toLowerCase()) {
      case 'jajan':                  return const Color(0xFF2DD4BF);
      case 'makan':                  return const Color(0xFFF472B6);
      case 'savings':                return const Color(0xFF4ADE80);
      case 'investment':             return const Color(0xFF60A5FA);
      case 'health':                 return const Color(0xFFFB7185);
      case 'mandatory share income': return const Color(0xFFA78BFA);
      case 'tarik tunai':            return const Color(0xFF94A3B8);
      case 'others':                 return const Color(0xFFFBBF24);
      default:                       return const Color(0xFF6C63FF);
    }
  }
}

// ── Category lists ────────────────────────────────────────────────────────────

abstract final class AppCategories {
  static const List<String> expense = <String>[
    'jajan', 'makan', 'savings', 'investment', 'health',
    'mandatory share income', 'tarik tunai', 'others',
  ];
  static const List<String> income = <String>[
    'salary', 'freelance', 'business', 'investment return',
    'bonus', 'gift', 'others',
  ];

  // Maps each expense category to its 50/30/20 bucket.
  static const Map<String, String> expenseNature = <String, String>{
    'makan':                  'needs',
    'health':                 'needs',
    'mandatory share income': 'needs',
    'tarik tunai':            'needs',
    'jajan':                  'wants',
    'others':                 'wants',
    'savings':                'savings',
    'investment':             'savings',
  };
}

// ── Theme ─────────────────────────────────────────────────────────────────────

abstract final class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.accent,
        secondary: AppColors.positive,
        surface:   AppColors.surface,
        error:     AppColors.negative,
        onPrimary:   Colors.white,
        onSecondary: Colors.black,
        onSurface:   AppColors.textPrimary,
        onError:     Colors.white,
      ),
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary, size: 22),
      ),
      // Bottom navigation (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 64,
        indicatorColor: Color(0x336C63FF),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.accent, size: 22);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(color: AppColors.textMuted, fontSize: 11);
        }),
      ),
      // Cards
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.negative),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.negative, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        prefixStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        suffixIconColor: AppColors.textMuted,
        errorStyle: const TextStyle(color: AppColors.negative, fontSize: 12),
      ),
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.textSecondary, fontSize: 14,
        ),
      ),
      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardLight,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        modalBackgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: Color(0x336C63FF),
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.divider, thickness: 1, space: 1,
      ),
      // Text
      textTheme: const TextTheme(
        headlineLarge:  TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, letterSpacing: -1.0),
        headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineSmall:  TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        titleLarge:     TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium:    TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        titleSmall:     TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        bodyLarge:      TextStyle(color: AppColors.textPrimary),
        bodyMedium:     TextStyle(color: AppColors.textSecondary),
        bodySmall:      TextStyle(color: AppColors.textSecondary, fontSize: 12),
        labelLarge:     TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        labelMedium:    TextStyle(color: AppColors.textSecondary, fontSize: 12),
        labelSmall:     TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.4),
      ),
    );
  }
}
