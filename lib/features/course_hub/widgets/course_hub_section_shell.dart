// Phase 6 — shared shell for every Course Hub section (MulhimIQ design system).
//
// Every section card on the unified Hub uses this same outer chrome
// (icon + title + optional badge + body slot + optional CTA). Restyled with
// the design system so all sections stay consistent with Student Home.

import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';

class CourseHubSectionShell extends StatelessWidget {
  const CourseHubSectionShell({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
    this.badge,
    this.action,
  });

  final IconData icon;
  final String title;
  final Widget? badge;
  final Widget? action;
  final Color? iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final c = iconColor ?? mq.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: MqCard(
        padding: const EdgeInsets.all(MqSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: MqRadius.brMd),
                  child: Icon(icon, color: c, size: MqSize.iconSm),
                ),
                MqSpacing.gapSm,
                Expanded(child: Text(title, style: context.text.titleSmall)),
                if (badge != null) ...[MqSpacing.gapXs, badge!],
                if (action != null) ...[MqSpacing.gapXs, action!],
              ],
            ),
            MqSpacing.gapMd,
            child,
          ],
        ),
      ),
    );
  }
}

/// Compact card-style row — leading icon chip + title + optional subtitle and
/// trailing (or an auto chevron when tappable). Used by the academic section
/// and others.
class CourseHubRow extends StatelessWidget {
  const CourseHubRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.sm),
      child: Material(
        color: mq.fill,
        shape: RoundedRectangleBorder(borderRadius: MqRadius.brMd, side: BorderSide(color: mq.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(MqSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brMd),
                  child: Icon(icon, size: MqSize.iconSm, color: mq.accent),
                ),
                MqSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: context.text.titleSmall),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[MqSpacing.gapXs, trailing!],
                if (onTap != null) ...[
                  MqSpacing.gapXs,
                  Icon(Icons.chevron_left_rounded, size: 20, color: mq.ink3),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny pill used in section badges (e.g. "5 جديد").
class CourseHubBadge extends StatelessWidget {
  const CourseHubBadge({super.key, required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final c = color ?? mq.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: MqRadius.brPill),
      child: Text(label, style: context.text.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w700)),
    );
  }
}

/// Loading skeleton used when a section is fetching its first payload.
class CourseHubSectionLoading extends StatelessWidget {
  const CourseHubSectionLoading({super.key, this.height = 60});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: context.mq.accent),
        ),
      ),
    );
  }
}

/// Inline error banner used by every section's error state.
class CourseHubSectionError extends StatelessWidget {
  const CourseHubSectionError({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return MqSurface(
      tone: MqSurfaceTone.neutral,
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: MqSize.iconSm, color: mq.error),
          MqSpacing.gapSm,
          Expanded(child: Text(message, style: context.text.bodySmall?.copyWith(color: mq.error))),
          if (onRetry != null)
            MqButton.text(label: 'إعادة المحاولة', size: MqButtonSize.small, onPressed: onRetry),
        ],
      ),
    );
  }
}
