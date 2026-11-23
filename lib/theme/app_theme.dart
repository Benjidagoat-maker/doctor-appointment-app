import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF117C72);
  static const Color primaryDark = Color(0xFF0C625B);
  static const Color accentTeal = Color(0xFF54B7AA);
  static const Color backgroundLight = Color(0xFFF2F7F6);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF172A28);
  static const Color textMuted = Color(0xFF687A77);
  static const Color dangerRed = Color(0xFFB54742);
  static const Color successGreen = Color(0xFF26866E);
  static const Color cardShadow = Color(0x0C000000);

  // ============================================================
  // Dashboard V22 Design System Tokens (Glowing Electric Blue & Glassmorphism)
  // ============================================================
  static const Color v22ElectricBlue = primaryBlue;
  static const Color v22ElectricCyan = accentTeal;
  static const Color v22DeepSlate = textDark;
  static const Color v22GlassBackground = Color(0xE6FFFFFF);
  static const Color v22GlassBorder = Color(0x33117C72);
  static const Color v22GlowShadow = Color(0x33117C72);

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
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: accentTeal,
        surface: surfaceWhite,
        error: dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: backgroundLight,
        foregroundColor: textDark,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE7E4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: cardShadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFDCE7E4)),
        ),
        color: surfaceWhite,
      ),
    );
  }
}
