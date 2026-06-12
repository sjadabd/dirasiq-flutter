import 'package:flutter/material.dart';

import 'mq_colors.dart';
import 'mq_spacing.dart';
import 'mq_typography.dart';

/// Assembles the MulhimIQ [ThemeData] for light and dark modes from the
/// design-system tokens. Component widgets read tokens through `context.mq`;
/// the base Material theming here keeps stock widgets (text fields, dialogs,
/// snackbars, etc.) on-brand without per-widget styling.
abstract final class MqTheme {
  static ThemeData light() => _build(MqColors.light, Brightness.light);
  static ThemeData dark() => _build(MqColors.dark, Brightness.dark);

  static ThemeData _build(MqColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.accentDeep,
      secondary: c.orange,
      onSecondary: c.ink,
      secondaryContainer: c.orangeSoft,
      onSecondaryContainer: c.orangeDeep,
      tertiary: c.success,
      onTertiary: c.onAccent,
      surface: c.card,
      onSurface: c.ink,
      surfaceContainerHighest: c.fill2,
      onSurfaceVariant: c.ink2,
      outline: c.line,
      outlineVariant: c.line2,
      error: c.error,
      onError: c.onAccent,
    );

    final textTheme = MqTypography.textTheme(ink: c.ink, muted: c.ink2);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.page,
      canvasColor: c.page,
      dividerColor: c.line,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[c],
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.card,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: c.ink),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: MqRadius.brLg),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.fill,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.lg, vertical: MqSpacing.md),
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.ink3),
        border: const OutlineInputBorder(
          borderRadius: MqRadius.brMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: MqRadius.brMd,
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: MqRadius.brMd,
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: MqRadius.brMd,
          borderSide: BorderSide(color: c.error),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.fill,
        selectedColor: c.accentSoft,
        side: BorderSide(color: c.line),
        labelStyle: textTheme.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: MqRadius.brPill),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.card),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: MqRadius.brMd),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: MqRadius.brXl),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(MqRadius.xl)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.fill2,
        circularTrackColor: c.fill2,
      ),
      iconTheme: IconThemeData(color: c.ink2),
    );
  }
}

/// Ergonomic access to the active [MqColors] token set: `context.mq.accent`.
///
/// Falls back to the brightness-matched token set when no [MqColors] extension
/// is registered on the active theme — so design-system widgets render
/// correctly even on screens not yet served by [MqTheme].
extension MqColorsX on BuildContext {
  MqColors get mq =>
      Theme.of(this).extension<MqColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? MqColors.dark
          : MqColors.light);

  TextTheme get text => Theme.of(this).textTheme;
}
