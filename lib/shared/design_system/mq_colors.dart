import 'package:flutter/material.dart';

/// MulhimIQ semantic color tokens, lifted verbatim from the design-system
/// export (the `--wf-*` CSS custom properties). Exposed as a [ThemeExtension]
/// so every token is light/dark aware via `Theme.of(context).extension<MqColors>()`
/// (or the `context.mq` shortcut in `mq_theme.dart`).
///
/// Token provenance is 1:1 with the HTML. `error` is the only addition — the
/// source palette ships no error red, so a neutral one is supplied here.
@immutable
class MqColors extends ThemeExtension<MqColors> {
  const MqColors({
    required this.page,
    required this.card,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.line2,
    required this.fill,
    required this.fill2,
    required this.accent,
    required this.accentDeep,
    required this.accentLine,
    required this.accentSoft,
    required this.accentShadow,
    required this.orange,
    required this.orangeDeep,
    required this.orangeLine,
    required this.orangeSoft,
    required this.success,
    required this.error,
    required this.onAccent,
    required this.cardShadow,
  });

  /// Scaffold / page background (`--wf-page`).
  final Color page;

  /// Raised surface — cards, sheets, app bars (`--wf-card`).
  final Color card;

  /// Primary text (`--wf-ink`).
  final Color ink;

  /// Secondary / muted text (`--wf-ink2`).
  final Color ink2;

  /// Tertiary / disabled text (`--wf-ink3`).
  final Color ink3;

  /// Default hairline border (`--wf-line`).
  final Color line;

  /// Faint divider (`--wf-line2`).
  final Color line2;

  /// Neutral filled surface — inputs, inactive chips (`--wf-fill`).
  final Color fill;

  /// Stronger neutral fill (`--wf-fill2`).
  final Color fill2;

  /// Brand blue — primary actions, active nav (`--wf-accent`).
  final Color accent;

  /// Deep navy variant — gradients, pressed states (`--wf-accent-deep`).
  final Color accentDeep;

  /// Tinted border on accent surfaces (`--wf-accent-line`).
  final Color accentLine;

  /// Soft accent wash — selected chips, info banners (`--wf-accent-soft`).
  final Color accentSoft;

  /// Shadow color for accent-elevated elements (`--wf-accent-shadow`).
  final Color accentShadow;

  /// Warm gold — highlights, ratings, streaks (`--wf-orange`).
  final Color orange;

  /// Deep orange variant (`--wf-orange-deep`).
  final Color orangeDeep;

  /// Border on orange surfaces (`--wf-orange-line`).
  final Color orangeLine;

  /// Soft orange wash — achievement badges (`--wf-orange-soft`).
  final Color orangeSoft;

  /// Success green (`--wf-success`).
  final Color success;

  /// Error red. Not in the source palette — supplied for form/validation use.
  final Color error;

  /// Foreground on accent / orange fills (`--wf-on-accent`).
  final Color onAccent;

  /// Resting card elevation (`--wf-card-shadow`).
  final List<BoxShadow> cardShadow;

  // ---- Light ----------------------------------------------------------------
  static const MqColors light = MqColors(
    page: Color(0xFFF8F9FB),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF111827),
    ink2: Color(0xFF6B7280),
    ink3: Color(0xFF9AA4B3),
    line: Color(0xFFEEF2F7),
    line2: Color(0xFFF4F6FA),
    fill: Color(0xFFF4F7FB),
    fill2: Color(0xFFE9EEF5),
    accent: Color(0xFF1F4D8F),
    accentDeep: Color(0xFF0F2C5C),
    accentLine: Color(0xFFCBDDF1),
    accentSoft: Color(0xFFE9F0F9),
    accentShadow: Color(0x471F4D8F), // rgba(31,77,143,0.28)
    orange: Color(0xFFF5A623),
    orangeDeep: Color(0xFFF57C22),
    orangeLine: Color(0xFFF7D89E),
    orangeSoft: Color(0xFFFEF2DC),
    success: Color(0xFF1FA971),
    error: Color(0xFFD64545),
    onAccent: Color(0xFFFFFFFF),
    cardShadow: [
      BoxShadow(color: Color(0x0D0F2C5C), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x0A0F2C5C), offset: Offset(0, 1), blurRadius: 3),
    ],
  );

  // ---- Dark -----------------------------------------------------------------
  static const MqColors dark = MqColors(
    page: Color(0xFF0B1A30),
    card: Color(0xFF13243D),
    ink: Color(0xFFEEF3FA),
    ink2: Color(0xFF9DB0CC),
    ink3: Color(0xFF67809F),
    line: Color(0xFF22395A),
    line2: Color(0xFF1A2D49),
    fill: Color(0xFF1A2E49),
    fill2: Color(0xFF23395B),
    accent: Color(0xFF4D86CE),
    accentDeep: Color(0xFF0F2C5C),
    accentLine: Color(0xFF2E5183),
    accentSoft: Color(0x294D86CE), // rgba(77,134,206,0.16)
    accentShadow: Color(0x73000000), // rgba(0,0,0,0.45)
    orange: Color(0xFFF7B53F),
    orangeDeep: Color(0xFFF57C22),
    orangeLine: Color(0x6BF7B53F), // rgba(247,181,63,0.42)
    orangeSoft: Color(0x26F7B53F), // rgba(247,181,63,0.15)
    success: Color(0xFF34C88A),
    error: Color(0xFFF08C8C),
    onAccent: Color(0xFFFFFFFF),
    cardShadow: [
      BoxShadow(color: Color(0x4D000000), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 8),
    ],
  );

  @override
  MqColors copyWith({
    Color? page,
    Color? card,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? line,
    Color? line2,
    Color? fill,
    Color? fill2,
    Color? accent,
    Color? accentDeep,
    Color? accentLine,
    Color? accentSoft,
    Color? accentShadow,
    Color? orange,
    Color? orangeDeep,
    Color? orangeLine,
    Color? orangeSoft,
    Color? success,
    Color? error,
    Color? onAccent,
    List<BoxShadow>? cardShadow,
  }) {
    return MqColors(
      page: page ?? this.page,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      fill: fill ?? this.fill,
      fill2: fill2 ?? this.fill2,
      accent: accent ?? this.accent,
      accentDeep: accentDeep ?? this.accentDeep,
      accentLine: accentLine ?? this.accentLine,
      accentSoft: accentSoft ?? this.accentSoft,
      accentShadow: accentShadow ?? this.accentShadow,
      orange: orange ?? this.orange,
      orangeDeep: orangeDeep ?? this.orangeDeep,
      orangeLine: orangeLine ?? this.orangeLine,
      orangeSoft: orangeSoft ?? this.orangeSoft,
      success: success ?? this.success,
      error: error ?? this.error,
      onAccent: onAccent ?? this.onAccent,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  MqColors lerp(covariant ThemeExtension<MqColors>? other, double t) {
    if (other is! MqColors) return this;
    return MqColors(
      page: Color.lerp(page, other.page, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      fill2: Color.lerp(fill2, other.fill2, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      accentLine: Color.lerp(accentLine, other.accentLine, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentShadow: Color.lerp(accentShadow, other.accentShadow, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      orangeDeep: Color.lerp(orangeDeep, other.orangeDeep, t)!,
      orangeLine: Color.lerp(orangeLine, other.orangeLine, t)!,
      orangeSoft: Color.lerp(orangeSoft, other.orangeSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t) ??
          cardShadow,
    );
  }
}
