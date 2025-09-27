import 'package:flutter/material.dart';

/// Centralized app color definitions and gradients
/// Colors designed for psychological comfort and user engagement
class AppColors {
  static const Color primary = Color(
    0xFF4A90E2,
  ); // Calming blue for trust and focus
  static const Color secondary = Color(
    0xFF7B68EE,
  ); // Inspiring purple for creativity
  static const Color tertiary = Color(
    0xFF20B2AA,
  ); // Refreshing teal for balance
  static const Color accent = Color(0xFFFF8A65); // Warm coral for motivation

  static const Color background = Color(
    0xFFF8FAFC,
  ); // Soft off-white for eye comfort
  static const Color surface = Color(0xFFFFFFFF); // Pure white for clarity
  static const Color surfaceVariant = Color(
    0xFFF1F5F9,
  ); // Light gray for subtle contrast
  static const Color textPrimary = Color(
    0xFF1E293B,
  ); // Dark slate for readability
  static const Color textSecondary = Color(
    0xFF64748B,
  ); // Medium gray for secondary text
  static const Color textTertiary = Color(0xFF94A3B8); // Light gray for hints
  static const Color outline = Color(0xFFE2E8F0); // Subtle borders

  static const Color success = Color(
    0xFF22C55E,
  ); // Vibrant green for achievement
  static const Color successLight = Color(0xFFDCFCE7); // Light green background
  static const Color warning = Color(0xFFF59E0B); // Warm amber for attention
  static const Color warningLight = Color(0xFFFEF3C7); // Light amber background
  static const Color error = Color(0xFFEF4444); // Clear red for errors
  static const Color errorLight = Color(0xFFFEE2E2); // Light red background
  static const Color info = Color(0xFF3B82F6); // Clear blue for information
  static const Color infoLight = Color(0xFFDBEAFE); // Light blue background

  static const Color focus = Color(0xFF6366F1); // Indigo for concentration
  static const Color energy = Color(0xFFEC4899); // Pink for enthusiasm
  static const Color calm = Color(0xFF06B6D4); // Cyan for relaxation
  static const Color growth = Color(0xFF10B981); // Emerald for progress

  // Common
  static const Color white = Colors.white;
  static const Color black = Color(0xFF0F172A); // Softer black

  static const List<Color> gradientWelcome = [
    Color(0xFF667EEA),
    Color(0xFF764BA2),
  ]; // Trust to creativity
  static const List<Color> gradientLearning = [
    Color(0xFF4FACFE),
    Color(0xFF00F2FE),
  ]; // Focus to clarity
  static const List<Color> gradientMotivation = [
    Color(0xFFFF9A9E),
    Color(0xFFFECFEF),
  ]; // Energy to comfort
  static const List<Color> gradientSuccess = [
    Color(0xFF11998E),
    Color(0xFF38EF7D),
  ]; // Growth to achievement
  static const List<Color> gradientCalm = [
    Color(0xFFA8EDEA),
    Color(0xFFFED6E3),
  ]; // Serenity to warmth
  static const List<Color> gradientInspiration = [
    Color(0xFFFFE259),
    Color(0xFFFFA751),
  ]; // Joy to enthusiasm

  static const List<Color> gradientMath = [
    Color(0xFF667EEA),
    Color(0xFF764BA2),
  ]; // Logic and reasoning
  static const List<Color> gradientScience = [
    Color(0xFF4FACFE),
    Color(0xFF00F2FE),
  ]; // Discovery and innovation
  static const List<Color> gradientLanguage = [
    Color(0xFFF093FB),
    Color(0xFFF5576C),
  ]; // Expression and creativity
  static const List<Color> gradientArt = [
    Color(0xFFFFE259),
    Color(0xFFFFA751),
  ]; // Creativity and joy

  static const Color buttonPrimary = Color(0xFF4A90E2);
  static const Color buttonPrimaryHover = Color(0xFF357ABD);
  static const Color buttonPrimaryPressed = Color(0xFF2563EB);
  static const Color buttonSecondary = Color(0xFFF1F5F9);
  static const Color buttonSecondaryHover = Color(0xFFE2E8F0);

  /// Enhanced ColorScheme with psychological considerations
  static ColorScheme lightScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
    primary: primary,
    secondary: secondary,
    tertiary: tertiary,
    surface: surface,
    background: background,
    error: error,
    onPrimary: white,
    onSecondary: white,
    onTertiary: white,
    onSurface: textPrimary,
    onBackground: textPrimary,
    onError: white,
  );

  /// Dark theme for eye comfort in low light
  static ColorScheme darkScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.dark,
    primary: Color(0xFF60A5FA),
    secondary: Color(0xFF9CA3AF),
    tertiary: Color(0xFF34D399),
    surface: Color(0xFF1E293B),
    background: Color(0xFF0F172A),
    error: Color(0xFFF87171),
    onPrimary: Color(0xFF0F172A),
    onSecondary: Color(0xFF0F172A),
    onTertiary: Color(0xFF0F172A),
    onSurface: Color(0xFFF8FAFC),
    onBackground: Color(0xFFF8FAFC),
    onError: Color(0xFF0F172A),
  );

  static Color getMotivationalColor(double progress) {
    if (progress < 0.3) return energy; // Pink for initial motivation
    if (progress < 0.7) return focus; // Indigo for sustained effort
    return success; // Green for achievement
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
