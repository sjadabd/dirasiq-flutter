import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'teacher_tokens.dart';

/// Teacher operations-dashboard component kit.
///
/// Built on top of the shared MulhimIQ design system ([MqCard], `context.mq`,
/// [MqSpacing], [MqRadius], [MqTypography]) plus the teacher-only [TeacherTokens]
/// status/hero layer. These give the teacher app its distinct "ops console"
/// character — KPI grids, status pills, titled dashboard cards, proportion
/// mini-charts, dense data rows — without the student marketplace cards.

/// Semantic tone shared by [TeacherStatusPill] and the KPI / stat accents.
enum TeacherTone { info, success, warning, danger, neutral }

({Color base, Color soft, Color line}) _tonePalette(
    BuildContext context, TeacherTone tone) {
  final t = context.teacher;
  final mq = context.mq;
  return switch (tone) {
    TeacherTone.info => (base: t.info, soft: t.infoSoft, line: t.infoLine),
    TeacherTone.success => (base: t.success, soft: t.successSoft, line: t.successLine),
    TeacherTone.warning => (base: t.warning, soft: t.warningSoft, line: t.warningLine),
    TeacherTone.danger => (base: t.danger, soft: t.dangerSoft, line: t.dangerLine),
    TeacherTone.neutral => (base: mq.ink2, soft: mq.fill2, line: mq.line),
  };
}

// ---------------------------------------------------------------------------
// TeacherStatusPill
// ---------------------------------------------------------------------------

/// A compact status pill — `قيد المراجعة`, `مدفوع`, `متأخر`, a live count.
/// Soft tinted fill + tone border + a leading dot (or icon). Non-interactive.
class TeacherStatusPill extends StatelessWidget {
  const TeacherStatusPill({
    super.key,
    required this.label,
    this.tone = TeacherTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final TeacherTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = _tonePalette(context, tone);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? MqSpacing.sm : MqSpacing.md,
        vertical: dense ? 3 : MqSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: MqRadius.brPill,
        border: Border.all(color: p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: p.base)
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: p.base, shape: BoxShape.circle),
            ),
          const SizedBox(width: MqSpacing.xs),
          Text(
            label,
            style: context.text.labelSmall
                ?.copyWith(color: p.base, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TeacherKpiCard
// ---------------------------------------------------------------------------

/// A headline metric tile for the dashboard KPI grid: tinted icon badge, a big
/// mono figure, a caption, and an optional trailing status pill (e.g. the
/// active-subset count). Numbers render with [MqTypography.mono] so the teacher
/// app keeps the same numeral treatment as the rest of MulhimIQ.
class TeacherKpiCard extends StatelessWidget {
  const TeacherKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = TeacherTone.info,
    this.caption,
    this.pill,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final TeacherTone tone;
  final String? caption;
  final Widget? pill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final p = _tonePalette(context, tone);

    return MqCard(
      onTap: onTap,
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(MqSpacing.sm),
                decoration: BoxDecoration(
                  color: p.soft,
                  borderRadius: MqRadius.brSm,
                  border: Border.all(color: p.line),
                ),
                child: Icon(icon, size: MqSize.iconSm, color: p.base),
              ),
              const Spacer(),
              if (pill != null) Flexible(child: pill!),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  maxLines: 1,
                  style: MqTypography.mono(
                      color: mq.ink, size: 24, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(color: mq.ink2),
              ),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: mq.ink3),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TeacherStatCard
// ---------------------------------------------------------------------------

/// A small inline stat tile (value over caption) for compact stat strips —
/// e.g. the three figures embedded in the dashboard hero. Designed to sit on a
/// translucent surface, so it takes an explicit [foreground]/[surface] pair
/// and doesn't assume the page background.
class TeacherStatCard extends StatelessWidget {
  const TeacherStatCard({
    super.key,
    required this.value,
    required this.caption,
    required this.foreground,
    required this.muted,
    required this.surface,
    required this.border,
    this.icon,
  });

  final String value;
  final String caption;
  final Color foreground;
  final Color muted;
  final Color surface;
  final Color border;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.sm, vertical: MqSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: MqSize.iconSm, color: foreground),
            const SizedBox(height: MqSpacing.xs),
          ],
          Text(
            value,
            maxLines: 1,
            style:
                MqTypography.mono(color: foreground, size: 18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TeacherDashboardCard
// ---------------------------------------------------------------------------

/// A titled section container: header row (icon + title + optional trailing
/// action / pill) over a body. The standard wrapper for every grouped block on
/// the dashboard (revenue summary, today's sessions, etc.).
class TeacherDashboardCard extends StatelessWidget {
  const TeacherDashboardCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.tone = TeacherTone.info,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final TeacherTone tone;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final p = _tonePalette(context, tone);

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: p.soft,
                    borderRadius: MqRadius.brSm,
                  ),
                  child: Icon(icon, size: MqSize.iconSm, color: p.base),
                ),
                const SizedBox(width: MqSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleSmall),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: context.text.labelSmall
                              ?.copyWith(color: mq.ink3)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TeacherDataRow
// ---------------------------------------------------------------------------

/// A dense label → value row for dashboard lists (revenue lines, session rows).
/// Optional leading icon, a value (mono if [mono]), and an optional trailing
/// widget such as a [TeacherStatusPill].
class TeacherDataRow extends StatelessWidget {
  const TeacherDataRow({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.iconTone = TeacherTone.neutral,
    this.valueColor,
    this.trailing,
    this.subtitle,
    this.mono = false,
    this.onTap,
    this.dividerBelow = false,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final TeacherTone iconTone;
  final Color? valueColor;
  final Widget? trailing;
  final String? subtitle;
  final bool mono;
  final VoidCallback? onTap;
  final bool dividerBelow;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final p = _tonePalette(context, iconTone);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: p.soft,
                borderRadius: MqRadius.brSm,
              ),
              child: Icon(icon, size: 16, color: p.base),
            ),
            const SizedBox(width: MqSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyMedium),
                if (subtitle != null)
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          context.text.labelSmall?.copyWith(color: mq.ink3)),
              ],
            ),
          ),
          const SizedBox(width: MqSpacing.sm),
          if (value != null)
            Text(
              value!,
              style: mono
                  ? MqTypography.mono(
                      color: valueColor ?? mq.ink, size: 15, weight: FontWeight.w700)
                  : context.text.labelLarge
                      ?.copyWith(color: valueColor ?? mq.ink),
            ),
          if (trailing != null) ...[
            if (value != null) const SizedBox(width: MqSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );

    final content = onTap == null
        ? row
        : InkWell(borderRadius: MqRadius.brSm, onTap: onTap, child: row);

    if (!dividerBelow) return content;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [content, Divider(height: 1, color: mq.line)],
    );
  }
}

// ---------------------------------------------------------------------------
// TeacherMiniChart
// ---------------------------------------------------------------------------

/// A single proportion segment for [TeacherMiniChart].
class TeacherChartSegment {
  const TeacherChartSegment(this.value, this.tone);
  final double value;
  final TeacherTone tone;
}

/// A compact stacked horizontal proportion bar — the dashboard mini-chart.
/// Renders real ratios (e.g. paid vs. remaining) over the [TeacherTokens.track]
/// background. No synthetic time-series: every segment is a real amount.
class TeacherMiniChart extends StatelessWidget {
  const TeacherMiniChart({
    super.key,
    required this.segments,
    this.height = 10,
  });

  final List<TeacherChartSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = context.teacher.track;
    final total = segments.fold<double>(0, (s, e) => s + (e.value <= 0 ? 0 : e.value));

    return ClipRRect(
      borderRadius: MqRadius.brPill,
      child: SizedBox(
        height: height,
        child: total <= 0
            ? ColoredBox(color: track)
            : Row(
                children: [
                  for (final seg in segments)
                    if (seg.value > 0)
                      Expanded(
                        flex: (seg.value / total * 1000).round().clamp(1, 1000000),
                        child: ColoredBox(
                          color: _tonePalette(context, seg.tone).base,
                        ),
                      ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TeacherEmptyState
// ---------------------------------------------------------------------------

/// Honest empty / not-yet-available state for a dashboard section. Used where
/// the backend has no endpoint yet (attendance rate, assignments/exams summary)
/// or a real list simply came back empty — never a fabricated number.
class TeacherEmptyState extends StatelessWidget {
  const TeacherEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.dense = false,
  });

  final String message;
  final IconData icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: dense ? MqSpacing.md : MqSpacing.xl),
      child: Column(
        children: [
          Icon(icon, size: dense ? 24 : 32, color: mq.ink3),
          const SizedBox(height: MqSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: mq.ink3),
          ),
        ],
      ),
    );
  }
}
