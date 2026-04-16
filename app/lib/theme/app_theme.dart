import 'package:flutter/material.dart';

class AppColors {
  // ── 메인 액센트 (그린) ─────────────────────────────
  static const accent       = Color(0xFF16A34A);
  static const accentLight  = Color(0xFFDCFCE7);
  static const accentDark   = Color(0xFF14532D);

  // ── 배경 / 서피스 ──────────────────────────────────
  static const background  = Color(0xFFF7F8FA);  // scaffold bg (섹션 구분)
  static const white       = Color(0xFFFFFFFF);  // 카드 bg
  static const surfaceAlt  = Color(0xFFF7F8FA);  // 인라인 섹션 구분

  // ── 텍스트 ────────────────────────────────────────
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint      = Color(0xFF9CA3AF);

  // ── 보더 ──────────────────────────────────────────
  static const border = Color(0xFFE5E7EB);

  // ── 영양소 차트 컬러 ──────────────────────────────
  static const carbColor    = Color(0xFF3B82F6);  // 탄수화물
  static const proteinColor = Color(0xFF10B981);  // 단백질
  static const fatColor     = Color(0xFFF59E0B);  // 지방

  // ── 상태 컬러 ─────────────────────────────────────
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFEF4444);
  static const info    = Color(0xFF3B82F6);

  // ── 레거시 aliases (기존 코드 호환) ──────────────
  static const green50  = Color(0xFFDCFCE7);
  static const green100 = Color(0xFFBBF7D0);
  static const green400 = Color(0xFF16A34A);
  static const green600 = Color(0xFF15803D);
  static const green800 = Color(0xFF14532D);

  static const gray50  = Color(0xFFF7F8FA);
  static const gray100 = Color(0xFFE5E7EB);
  static const gray200 = Color(0xFF9CA3AF);
  static const gray400 = Color(0xFF6B7280);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      secondary: AppColors.accentDark,
      surface: AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'Pretendard',
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(double.infinity, 48),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: 'Pretendard',
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(double.infinity, 48),
        textStyle: const TextStyle(
          fontSize: 15,
          fontFamily: 'Pretendard',
        ),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      hintStyle: const TextStyle(
        color: AppColors.textHint,
        fontSize: 14,
        fontFamily: 'Pretendard',
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.accent,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Pretendard'),
      unselectedLabelStyle: TextStyle(fontSize: 13, fontFamily: 'Pretendard'),
      indicatorColor: AppColors.accent,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.border,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 0.5,
      space: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(
        color: AppColors.white,
        fontSize: 13,
        fontFamily: 'Pretendard',
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // ── 공용 카드 데코레이션 ───────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.border),
    boxShadow: const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
  );
}
