import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

/// Teacher-area design tokens.
///
/// The teacher operations UI shares the MulhimIQ brand base (`--wf-*`, exposed
/// as [MqColors] / `context.mq`) so the teacher and student apps stay visually
/// related — same brand blue, same surfaces, same Cairo type. What makes the
/// teacher experience *distinct* is this extra layer lifted verbatim from the
/// Teacher design export's `--t-*` custom properties: the status-pill palette
/// (success / warning / danger / info), the dashboard hero gradient, the flat
/// nav bar surface, and the mini-chart track.
///
/// These are intentionally NOT in [MqColors] — they're operations-dashboard
/// chrome that the student marketplace never uses. Access the active set with
/// `TeacherTokens.of(context)`.
@immutable
class TeacherTokens {
  const TeacherTokens({
    required this.success,
    required this.successSoft,
    required this.successLine,
    required this.warning,
    required this.warningSoft,
    required this.warningLine,
    required this.danger,
    required this.dangerSoft,
    required this.dangerLine,
    required this.info,
    required this.infoSoft,
    required this.infoLine,
    required this.heroA,
    required this.heroB,
    required this.heroInk,
    required this.heroInk2,
    required this.heroLine,
    required this.heroTile,
    required this.navBar,
    required this.track,
    required this.shadowLg,
  });

  // Status palette — drives [TeacherStatusPill] and KPI accents.
  final Color success, successSoft, successLine;
  final Color warning, warningSoft, warningLine;
  final Color danger, dangerSoft, dangerLine;
  final Color info, infoSoft, infoLine;

  // Dashboard hero strip gradient + on-gradient inks.
  final Color heroA, heroB, heroInk, heroInk2, heroLine, heroTile;

  /// Flat bottom-nav surface (`--t-navbar`).
  final Color navBar;

  /// Mini-chart / proportion-bar track (`--t-track`).
  final Color track;

  /// Elevated shadow for the hero + raised cards (`--t-shadow-lg`).
  final List<BoxShadow> shadowLg;

  static const TeacherTokens light = TeacherTokens(
    success: Color(0xFF1FA971),
    successSoft: Color(0xFFE6F6EF),
    successLine: Color(0xFFBBE6D3),
    warning: Color(0xFFF57C22),
    warningSoft: Color(0xFFFEF1E5),
    warningLine: Color(0xFFF8D2B0),
    danger: Color(0xFFE5484D),
    dangerSoft: Color(0xFFFDEBEC),
    dangerLine: Color(0xFFF6C9CB),
    info: Color(0xFF1F4D8F),
    infoSoft: Color(0xFFE9F0F9),
    infoLine: Color(0xFFCBDDF1),
    heroA: Color(0xFF10336B),
    heroB: Color(0xFF1F4D8F),
    heroInk: Color(0xFFEAF1FB),
    heroInk2: Color(0xFFA9C2E6),
    heroLine: Color(0x24FFFFFF), // rgba(255,255,255,0.14)
    heroTile: Color(0x12FFFFFF), // rgba(255,255,255,0.07)
    navBar: Color(0xFFFFFFFF),
    track: Color(0xFFEAEFF6),
    shadowLg: [
      BoxShadow(color: Color(0x1A0F2C5C), offset: Offset(0, 8), blurRadius: 28),
    ],
  );

  static const TeacherTokens dark = TeacherTokens(
    success: Color(0xFF34C88A),
    successSoft: Color(0x2434C88A), // rgba(52,200,138,0.14)
    successLine: Color(0x4D34C88A), // rgba(52,200,138,0.3)
    warning: Color(0xFFF7913F),
    warningSoft: Color(0x24F7913F),
    warningLine: Color(0x4DF7913F),
    danger: Color(0xFFFF6166),
    dangerSoft: Color(0x24FF6166),
    dangerLine: Color(0x52FF6166), // rgba(255,97,102,0.32)
    info: Color(0xFF4D86CE),
    infoSoft: Color(0x294D86CE), // rgba(77,134,206,0.16)
    infoLine: Color(0xFF2E5183),
    heroA: Color(0xFF0A1E3C),
    heroB: Color(0xFF143661),
    heroInk: Color(0xFFEAF1FB),
    heroInk2: Color(0xFF92ABCF),
    heroLine: Color(0x1AFFFFFF), // rgba(255,255,255,0.10)
    heroTile: Color(0x0DFFFFFF), // rgba(255,255,255,0.05)
    navBar: Color(0xFF0F2138),
    track: Color(0xFF1C3252),
    shadowLg: [
      BoxShadow(color: Color(0x66000000), offset: Offset(0, 10), blurRadius: 30),
    ],
  );

  static TeacherTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? TeacherTokens.dark
          : TeacherTokens.light;
}

/// Ergonomic access: `context.teacher.success`.
extension TeacherTokensX on BuildContext {
  TeacherTokens get teacher => TeacherTokens.of(this);
}
