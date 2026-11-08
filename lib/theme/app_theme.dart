import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF0F67FE);
  static const Color primaryDark = Color(0xFF0A3C9E);
  static const Color accentTeal = Color(0xFF00C9A7);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);
  static const Color cardShadow = Color(0x0C000000);

  // ============================================================
  // Dashboard V22 Design System Tokens (Glowing Electric Blue & Glassmorphism)
  // ============================================================
  static const Color v22ElectricBlue = Color(0xFF0066FF);
  static const Color v22ElectricCyan = Color(0xFF00D2FF);
  static const Color v22DeepSlate = Color(0xFF0B192C);
  static const Color v22GlassBackground = Color(0xE6FFFFFF); // 90% opacity frosted glass
  static const Color v22GlassBorder = Color(0x2E0066FF);     // subtle electric blue rim
  static const Color v22GlowShadow = Color(0x330066FF);

  static const LinearGradient v22ElectricGradient = LinearGradient(
    colors: [v22ElectricBlue, v22ElectricCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient v22GlassGradient = LinearGradient(
    colors: [
      Color(0xF0FFFFFF),
      Color(0xCCF0F7FF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration v22GlassCard({
    double radius = 18.0,
    Color borderColor = v22GlassBorder,
    List<BoxShadow>? extraShadows,
  }) {
    return BoxDecoration(
      gradient: v22GlassGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1.2),
      boxShadow: extraShadows ??
          [
            BoxShadow(
              color: v22GlowShadow.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            const BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: v22ElectricBlue,
        primary: v22ElectricBlue,
        secondary: v22ElectricCyan,
        surface: surfaceWhite,
        error: dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: surfaceWhite,
        foregroundColor: textDark,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: v22ElectricBlue, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: v22ElectricBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: cardShadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: surfaceWhite,
      ),
    );
  }
}
