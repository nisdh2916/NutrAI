import 'package:flutter/material.dart';

class AppColors {
  // Primary green palette
  static const green50  = Color(0xFFEAF3DE);
  static const green100 = Color(0xFFC0DD97);
  static const green400 = Color(0xFF639922);
  static const green600 = Color(0xFF3B6D11);
  static const green800 = Color(0xFF27500A);

  // Gray palette
  static const gray50  = Color(0xFFF1EFE8);
  static const gray100 = Color(0xFFD3D1C7);
  static const gray200 = Color(0xFFB4B2A9);
  static const gray400 = Color(0xFF888780);

  static const white       = Color(0xFFFFFFFF);
  static const background  = Color(0xFFF5F6F3);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B6B6B);
  static const border      = Color(0xFFE0DED8);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard', // pubspec.yaml에 폰트 추가 필요
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
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green400,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 50),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.gray50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.green400, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.gray200, fontSize: 14),
    ),
  );
}
