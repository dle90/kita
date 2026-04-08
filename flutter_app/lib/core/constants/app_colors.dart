import 'package:flutter/material.dart';

/// Vibrant, playful color palette for Kita English.
/// Inspired by Duolingo Kids / Khan Academy Kids — saturated, joyful, high contrast.
class AppColors {
  AppColors._();

  // Primary palette — vibrant purple-blue (playful, trustworthy)
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFFA29BFE);
  static const Color primaryDark = Color(0xFF4834D4);

  // Secondary palette — bright coral-orange (energy, fun)
  static const Color secondary = Color(0xFFFF6B6B);
  static const Color secondaryLight = Color(0xFFFF9F9F);
  static const Color secondaryDark = Color(0xFFEE5A24);

  // Accent — sunny yellow (celebration, attention)
  static const Color accent = Color(0xFFFFD93D);
  static const Color accentLight = Color(0xFFFFE66D);

  // Tertiary — turquoise (fresh, calm)
  static const Color tertiary = Color(0xFF00D2D3);
  static const Color tertiaryLight = Color(0xFF7EFCF6);

  // Semantic colors — brighter, more saturated
  static const Color success = Color(0xFF00B894);
  static const Color successLight = Color(0xFF55EFC4);
  static const Color error = Color(0xFFFF6B6B);
  static const Color errorLight = Color(0xFFFFAAAA);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color warningLight = Color(0xFFFEE9A0);

  // Background & surface — warm, soft, inviting
  static const Color background = Color(0xFFFFF8F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0EEFF);
  static const Color scaffoldBackground = Color(0xFFFFF5EB);

  // Text colors — softer black, kid-friendly
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color textHint = Color(0xFFB2BEC3);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);

  // Star colors — golden and shiny
  static const Color starFilled = Color(0xFFFFD700);
  static const Color starEmpty = Color(0xFFDFE6E9);

  // Character mascot colors — vibrant and distinct
  static const Color mochiCat = Color(0xFFFF6B81);          // Hot pink
  static const Color mochiCatAccent = Color(0xFFFFCCD5);
  static const Color rongDragon = Color(0xFF00B894);         // Mint green
  static const Color rongDragonAccent = Color(0xFF55EFC4);
  static const Color luaBird = Color(0xFFFFD93D);            // Sunny yellow
  static const Color luaBirdAccent = Color(0xFFFFE66D);
  static const Color boRobot = Color(0xFF74B9FF);            // Sky blue
  static const Color boRobotAccent = Color(0xFFA8D8FF);

  // Activity-specific colors
  static const Color correctAnswer = Color(0xFF00B894);
  static const Color wrongAnswer = Color(0xFFFF6B6B);
  static const Color neutralOption = Color(0xFFF0EEFF);
  static const Color selectedOption = Color(0xFFD1C4E9);

  // Pronunciation score colors
  static const Color pronExcellent = Color(0xFF00B894);    // ≥80
  static const Color pronGood = Color(0xFFFDCB6E);          // 50-80
  static const Color pronNeedsWork = Color(0xFFFF6B6B);     // <50

  // Gradient presets — fun and eye-catching
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFFD93D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient celebrationGradient = LinearGradient(
    colors: [Color(0xFFFF6B81), Color(0xFFFFD93D), Color(0xFF00B894)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient skyGradient = LinearGradient(
    colors: [Color(0xFFA29BFE), Color(0xFF74B9FF), Color(0xFF7EFCF6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF9F9F), Color(0xFFFFD93D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Returns the color for a given character ID.
  static Color characterColor(String characterId) {
    switch (characterId) {
      case 'mochi':
        return mochiCat;
      case 'rong':
        return rongDragon;
      case 'lua':
        return luaBird;
      case 'bo':
        return boRobot;
      default:
        return primary;
    }
  }

  /// Returns the accent color for a given character ID.
  static Color characterAccent(String characterId) {
    switch (characterId) {
      case 'mochi':
        return mochiCatAccent;
      case 'rong':
        return rongDragonAccent;
      case 'lua':
        return luaBirdAccent;
      case 'bo':
        return boRobotAccent;
      default:
        return primaryLight;
    }
  }
}
