/// Teacher operations design system.
///
/// Single import for the teacher-area UI: the shared MulhimIQ design system
/// (tokens, theme, MqCard/MqButton/MqBadge/...) plus the teacher-only
/// [TeacherTokens] status/hero layer and the operations component kit
/// (TeacherKpiCard, TeacherStatCard, TeacherDashboardCard, TeacherStatusPill,
/// TeacherMiniChart, TeacherDataRow).
///
/// ```dart
/// import 'package:mulhimiq/features/teacher/shared/design/teacher_design.dart';
/// ```
library;

export 'package:mulhimiq/shared/design_system/design_system.dart';

export 'teacher_tokens.dart';
export 'teacher_components.dart';
