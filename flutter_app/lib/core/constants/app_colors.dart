import 'package:flutter/material.dart';

/// Bright, kid-friendly color palette for Kita English.
class AppColors {
  AppColors._();

  // Primary palette
  static const Color primary = Color(0xFF4A90D9);
  static const Color primaryLight = Color(0xFF7BB3E8);
  static const Color primaryDark = Color(0xFF2D6BB5);

  // Secondary palette (warm orange)
  static const Color secondary = Color(0xFFFF8C42);
  static const Color secondaryLight = Color(0xFFFFAD70);
  static const Color secondaryDark = Color(0xFFE06B1F);

  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color error = Color(0xFFEF6C6C);
  static const Color errorLight = Color(0xFFF5A3A3);
  static const Color warning = Color(0xFFFFCA28);
  static const Color warningLight = Color(0xFFFFE082);

  // Background & surface
  static const Color background = Color(0xFFF8F6FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0EDFA);
  static const Color scaffoldBackground = Color(0xFFF5F3FF);

  // Text colors
  static const Color textPrimary = Color(0xFF2D2D3A);
  static const Color textSecondary = Color(0xFF6B6B80);
  static const Color textHint = Color(0xFFA0A0B2);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);

  // Star colors
  static const Color starFilled = Color(0xFFFFD700);
  static const Color starEmpty = Color(0xFFE0E0E0);

  // Character mascot colors
  static const Color mochiCat = Color(0xFFFF9FB0);        // Soft pink
  static const Color mochiCatAccent = Color(0xFFFFD1DA);
  static const Color rongDragon = Color(0xFF7CD992);      // Lively green
  static const Color rongDragonAccent = Color(0xFFB8F0C8);
  static const Color luaBird = Color(0xFFFFD166);          // Golden yellow
  static const Color luaBirdAccent = Color(0xFFFFE599);
  static const Color boRobot = Color(0xFF6EC6FF);          // Sky blue
  static const Color boRobotAccent = Color(0xFFA8DDFF);

  // Activity-specific colors
  static const Color correctAnswer = Color(0xFF4CAF50);
  static const Color wrongAnswer = Color(0xFFEF6C6C);
  static const Color neutralOption = Color(0xFFE8E5F0);
  static const Color selectedOption = Color(0xFFD1C4E9);

  // Pronunciation score colors
  static const Color pronExcellent = Color(0xFF4CAF50);   // >80
  static const Color pronGood = Color(0xFFFFCA28);         // 50-80
  static const Color pronNeedsWork = Color(0xFFEF6C6C);   // <50

  // Gradient presets
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient celebrationGradient = LinearGradient(
    colors: [Color(0xFFFF9FB0), Color(0xFFFFD166), Color(0xFF7CD992)],
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
