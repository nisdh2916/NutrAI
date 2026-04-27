import 'package:flutter/material.dart';

// ── Toss TDS inspired design tokens ──────────────────────────
class AppColors {
  // Background / Surface
  static const bg         = Color(0xFFF2F4F6); // page background
  static const bgAlt      = Color(0xFFF9FAFB); // alt background
  static const surface    = Color(0xFFFFFFFF); // card surface
  static const line       = Color(0xFFE5E8EB); // hairline
  static const lineSoft   = Color(0xFFF2F4F6); // soft divider
  static const lineStrong = Color(0xFFD1D6DB); // stronger divider

  // Text
  static const text         = Color(0xFF191F28); // primary
  static const textSub      = Color(0xFF4E5968); // secondary
  static const textMuted    = Color(0xFF8B95A1); // tertiary
  static const textDisabled = Color(0xFFB0B8C1); // disabled

  // Brand — NutrAI green
  static const brand      = Color(0xFF22A447);
  static const brandDark  = Color(0xFF1E8E3E);
  static const brandSoft  = Color(0xFFE6F4EA);
  static const brandText  = Color(0xFF1A7F36);

  // Semantic accents
  static const blue       = Color(0xFF3182F6);
  static const blueSoft   = Color(0xFFE8F3FF);
  static const red        = Color(0xFFF04452);
  static const redSoft    = Color(0xFFFEECEE);
  static const orange     = Color(0xFFFF9500);
  static const orangeSoft = Color(0xFFFFF4E5);
  static const yellow     = Color(0xFFFFCC00);

  // Nutrition semantic
  static const carb        = Color(0xFF3182F6);
  static const carbSoft    = Color(0xFFE8F3FF);
  static const protein     = Color(0xFF22A447);
  static const proteinSoft = Color(0xFFE6F4EA);
  static const fat         = Color(0xFFFF9500);
  static const fatSoft     = Color(0xFFFFF4E5);

  // Meal semantic
  static const breakfast     = Color(0xFF3182F6);
  static const breakfastSoft = Color(0xFFE8F3FF);
  static const lunch         = Color(0xFF22A447);
  static const lunchSoft     = Color(0xFFE6F4EA);
  static const dinner        = Color(0xFF8B5CF6);
  static const dinnerSoft    = Color(0xFFF3EEFE);

  // Legacy aliases (used in existing code — map to new tokens)
  static const white          = surface;
  static const background     = bg;
  static const textPrimary    = text;
  static const textSecondary  = textSub;
  static const border         = line;
  static const green50        = brandSoft;
  static const green100       = Color(0xFFC8E6C9);
  static const green400       = brand;
  static const green600       = brandDark;
  static const green800       = brandText;
  static const gray50         = lineSoft;
  static const gray100        = lineStrong;
  static const gray200        = textDisabled;
  static const gray400        = textMuted;
}

// ── Border radius ─────────────────────────────────────────────
class AppRadius {
  static const xs   = 6.0;
  static const sm   = 8.0;
  static const md   = 12.0;
  static const lg   = 16.0;
  static const xl   = 20.0;
  static const xxl  = 24.0;
  static const pill = 999.0;
}

// ── Shadows ───────────────────────────────────────────────────
class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2,  offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 4,  offset: Offset(0, 2)),
    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const fab = [
    BoxShadow(color: Color(0x5922A447), blurRadius: 20, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x1A000000), blurRadius: 6,  offset: Offset(0, 2)),
  ];
  static const card2 = [
    BoxShadow(
      color: Color(0x1A111827),
      blurRadius: 24, spreadRadius: -8, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A111827), blurRadius: 6, offset: Offset(0, 2)),
  ];
}

// ── Theme ─────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      secondary: AppColors.brandDark,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.015,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.015),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lineSoft,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
    ),
  );
}
