import 'package:flutter/material.dart';

class AppColors {
  // ── 메인 그린 (sage/올리브) ───────────────────────
  static const green400 = Color(0xFF7CB342);  // 메인 액센트
  static const green300 = Color(0xFF9CCC65);  // 그라디언트 끝 / 라이트
  static const green200 = Color(0xFFA5D6A7);  // 보조, 배경 틴트
  static const green600 = Color(0xFF558B2F);  // 강조
  static const green50  = Color(0xFFF1F8E9);  // 챗봇 메시지 bg
  static const green100 = Color(0xFFDCEDC8);  // 보더 틴트

  // ── 배경 / 서피스 ──────────────────────────────────
  static const background = Color(0xFFFAFAF7);  // 따뜻한 오프화이트
  static const white      = Color(0xFFFFFFFF);

  // ── 파스텔 카드 배경 ──────────────────────────────
  static const morningCard  = Color(0xFFFFF4E1);  // 아침 크림
  static const lunchCard    = Color(0xFFE8F5E9);  // 점심 민트
  static const dinnerCard   = Color(0xFFFFE5E5);  // 저녁 피치
  static const botBubble    = Color(0xFFF1F8E9);  // 챗봇 메시지 연두
  static const snackCard    = Color(0xFFF3E5F5);  // 간식 라벤더

  // ── 텍스트 ────────────────────────────────────────
  static const textPrimary   = Color(0xFF2E2E2E);
  static const textSecondary = Color(0xFF757575);
  static const textHint      = Color(0xFFBDBDBD);

  // ── 보더 (사용 최소화) ────────────────────────────
  static const border = Color(0xFFE8E8E4);

  // ── 영양소 차트 (소프트) ──────────────────────────
  static const carbColor    = Color(0xFF64B5F6);  // 소프트 블루
  static const proteinColor = Color(0xFF81C784);  // 소프트 그린
  static const fatColor     = Color(0xFFFFB74D);  // 소프트 앰버

  // ── 상태 ──────────────────────────────────────────
  static const success = Color(0xFF7CB342);
  static const warning = Color(0xFFFF8A65);
  static const info    = Color(0xFF64B5F6);

  // ── 레거시 aliases ────────────────────────────────
  static const gray50  = Color(0xFFF5F5F5);
  static const gray100 = Color(0xFFE0E0E0);
  static const gray200 = Color(0xFFBDBDBD);
  static const gray400 = Color(0xFF757575);
  static const green800 = Color(0xFF33691E);
}

class AppTheme {
  // ── 그라디언트 (CTA 버튼용) ───────────────────────
  static const primaryGradient = LinearGradient(
    colors: [AppColors.green400, AppColors.green300],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── 카드 그림자 ───────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    const BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green400,
      primary: AppColors.green400,
      secondary: AppColors.green600,
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
        fontSize: 17,
        fontWeight: FontWeight.w700,
        fontFamily: 'Pretendard',
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green400,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: 'Pretendard',
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        minimumSize: const Size(double.infinity, 52),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.green400, width: 2),
      ),
      hintStyle: const TextStyle(
        color: AppColors.textHint,
        fontSize: 15,
        fontFamily: 'Pretendard',
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.green600,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Pretendard'),
      unselectedLabelStyle: TextStyle(fontSize: 14, fontFamily: 'Pretendard'),
      indicatorColor: AppColors.green400,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.border,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 0.5,
      space: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.green400,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.green600,
      contentTextStyle: const TextStyle(
        color: AppColors.white,
        fontSize: 14,
        fontFamily: 'Pretendard',
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
