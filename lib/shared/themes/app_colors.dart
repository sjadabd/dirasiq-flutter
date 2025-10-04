import 'package:flutter/material.dart';

/// 🎨 App Colors for Light & Dark Themes
/// Based on the selected professional LMS design
class AppColors {
  // ===== 🌞 Light Theme Colors =====
  static const Color primary = Color(0xFF1E3A8A); // Blue Dark (header/buttons)
  static const Color secondary = Color(0xFF4ADE80); // Green success
  static const Color tertiary = Color(0xFF0EA5E9); // Cyan/Teal for balance
  static const Color accent = Color(0xFFF59E0B); // Amber/Highlight

  static const Color background = Color(0xFFF9FAFB); // Very light background
  static const Color surface = Color(0xFFFFFFFF); // White cards
  static const Color surfaceVariant = Color(0xFFF3F4F6); // Light gray

  static const Color textPrimary = Color(0xFF111827); // Near black
  static const Color textSecondary = Color(0xFF6B7280); // Gray
  static const Color textTertiary = Color(0xFF9CA3AF); // Light gray
  static const Color outline = Color(0xFFE5E7EB); // Subtle border

  static const Color success = Color(0xFF22C55E); // Green
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFFACC15); // Yellow warning
  static const Color warningLight = Color(0xFFFEF9C3);
  static const Color error = Color(0xFFEF4444); // Red
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0284C7); // Blue info
  static const Color infoLight = Color(0xFFDBEAFE);

  // ===== 🌙 Dark Theme Colors =====
  static const Color darkBackground = Color(0xFF0F172A); // Dark navy
  static const Color darkSurface = Color(0xFF1F2937); // Dark gray surface
  static const Color darkSurfaceVariant = Color(0xFF374151); // Mid gray

  static const Color darkTextPrimary = Color(0xFFF9FAFB); // White-ish
  static const Color darkTextSecondary = Color(0xFFD1D5DB); // Light gray
  static const Color darkTextTertiary = Color(0xFF9CA3AF);

  static const Color darkPrimary = Color(0xFF60A5FA); // Light blue
  static const Color darkSecondary = Color(0xFF34D399); // Emerald green
  static const Color darkTertiary = Color(0xFF0EA5E9); // Cyan
  static const Color darkAccent = Color(0xFFFBBF24); // Warm amber

  // Common
  static const Color white = Colors.white;
  static const Color black = Color(0xFF0F172A);

  // Emotional/mood aliases
  static const Color energy = accent; // Accent as energy
  static const Color focus = secondary; // Secondary as focus

  // ===== 🌈 Gradients =====
  static const List<Color> gradientWelcome = [
    primary,
    secondary,
  ]; // Blue → Green

  static const List<Color> gradientLearning = [
    Color(0xFF38BDF8),
    Color(0xFF0EA5E9),
  ]; // Cyan Gradient

  static const List<Color> gradientMotivation = [
    Color(0xFFFECACA),
    Color(0xFFFB7185),
  ]; // Soft Red → Pink

  static const List<Color> gradientSuccess = [
    Color(0xFF4ADE80),
    Color(0xFF16A34A),
  ]; // Green

  static const List<Color> gradientCalm = [
    Color(0xFFA5F3FC),
    Color(0xFF67E8F9),
  ]; // Soft Cyan

  static const List<Color> gradientInspiration = [
    Color(0xFFFDE68A),
    Color(0xFFFBBF24),
  ]; // Yellow/Amber

  // Subject-specific
  static const List<Color> gradientMath = [primary, secondary];
  static const List<Color> gradientScience = [
    Color(0xFF38BDF8),
    Color(0xFF0EA5E9),
  ];
  static const List<Color> gradientLanguage = [
    Color(0xFFFB7185),
    Color(0xFFF472B6),
  ];
  static const List<Color> gradientArt = [Color(0xFFFDE68A), Color(0xFFFBBF24)];

  // ===== Buttons =====
  static const Color buttonPrimary = primary;
  static const Color buttonPrimaryHover = Color(0xFF1D4ED8);
  static const Color buttonPrimaryPressed = Color(0xFF1E40AF);
  static const Color buttonSecondary = surfaceVariant;
  static const Color buttonSecondaryHover = outline;

  // ===== 🎨 Theme Schemes =====
  static ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    secondary: secondary,
    tertiary: tertiary,
    surface: surface,
    error: error,
    onPrimary: white,
    onSecondary: white,
    onTertiary: white,
    onSurface: textPrimary,
    onError: white,
  );

  static ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: darkPrimary,
    secondary: darkSecondary,
    tertiary: darkTertiary,
    surface: darkSurface,
    error: darkAccent,
    onPrimary: white,
    onSecondary: white,
    onTertiary: white,
    onSurface: darkTextPrimary,
    onError: white,
  );

  static Color get border => outline;

  static Color getMotivationalColor(double progress) {
    if (progress < 0.3) return energy;
    if (progress < 0.7) return focus;
    return success;
  }

  static LinearGradient getSubjectGradient(String subject) {
    switch (subject.toLowerCase()) {
      case 'math':
      case 'mathematics':
        return LinearGradient(colors: gradientMath);
      case 'science':
      case 'physics':
      case 'chemistry':
        return LinearGradient(colors: gradientScience);
      case 'language':
      case 'arabic':
      case 'english':
        return LinearGradient(colors: gradientLanguage);
      case 'art':
      case 'drawing':
        return LinearGradient(colors: gradientArt);
      default:
        return LinearGradient(colors: gradientWelcome);
    }
  }
}
