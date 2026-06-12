import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography for the MulhimIQ design system.
///
/// The export uses **Cairo** (the app-wide Arabic typeface) for all UI text and
/// **IBM Plex Mono** for numeric callouts (the `92%`, `4.9`, `+50` stat
/// figures). Mono is deliberately kept for stats so percentages, grades,
/// currency, countdowns, and statistics keep their fixed-width number
/// rendering. Both are pulled from `google_fonts` so no asset bundling is
/// required.
///
/// Weight hierarchy (Cairo): Display/Hero & Screen Titles → w700, Section
/// Titles & Buttons → w600, Body & Captions → w400.
abstract final class MqTypography {
  static TextStyle _sans({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.cairo(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Monospaced numerals for stats / metrics (IBM Plex Mono).
  static TextStyle mono({
    required Color color,
    double size = 16,
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.2,
    );
  }

  /// Builds a Material [TextTheme] keyed off the resolved ink colors.
  ///
  /// [ink] drives headings and body; [muted] drives the smaller/secondary
  /// roles (`bodySmall`, `labelSmall`).
  static TextTheme textTheme({required Color ink, required Color muted}) {
    return TextTheme(
      displaySmall: _sans(
          size: 24, weight: FontWeight.w700, color: ink, letterSpacing: -0.2, height: 1.2),
      headlineMedium: _sans(
          size: 22, weight: FontWeight.w700, color: ink, letterSpacing: -0.2, height: 1.2),
      headlineSmall: _sans(
          size: 20, weight: FontWeight.w700, color: ink, letterSpacing: -0.2, height: 1.25),
      titleLarge: _sans(
          size: 18, weight: FontWeight.w700, color: ink, letterSpacing: -0.2, height: 1.3),
      titleMedium:
          _sans(size: 16, weight: FontWeight.w700, color: ink, height: 1.35),
      titleSmall:
          _sans(size: 15, weight: FontWeight.w600, color: ink, height: 1.35),
      bodyLarge:
          _sans(size: 15, weight: FontWeight.w400, color: ink, height: 1.5),
      bodyMedium:
          _sans(size: 14, weight: FontWeight.w400, color: ink, height: 1.5),
      bodySmall:
          _sans(size: 13, weight: FontWeight.w400, color: muted, height: 1.45),
      labelLarge:
          _sans(size: 14, weight: FontWeight.w600, color: ink, height: 1.2),
      labelMedium:
          _sans(size: 12, weight: FontWeight.w500, color: muted, height: 1.2),
      labelSmall:
          _sans(size: 11, weight: FontWeight.w500, color: muted, height: 1.2),
    );
  }
}
