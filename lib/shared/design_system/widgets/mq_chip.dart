import 'package:flutter/material.dart';

import '../mq_spacing.dart';
import '../mq_theme.dart';

/// Pill-shaped selectable filter chip — the `الكل / الفيزياء / الرياضيات`
/// filter row in the export. Selected chips fill with the soft accent wash and
/// pick up the accent border + ink.
class MqChip extends StatelessWidget {
  const MqChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final bg = selected ? mq.accentSoft : mq.fill;
    final border = selected ? mq.accent : mq.line;
    final fg = selected ? mq.accent : mq.ink2;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: MqRadius.brPill,
        side: BorderSide(color: border, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: MqSpacing.lg, vertical: MqSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: MqSize.iconSm, color: fg),
                MqSpacing.gapXs,
              ],
              Text(
                label,
                style: context.text.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Semantic tone for an [MqBadge].
enum MqBadgeTone { neutral, accent, orange, success, error }

/// A compact status pill (e.g. course level `ثانوي`, a count, or a state
/// label). Non-interactive by design.
class MqBadge extends StatelessWidget {
  const MqBadge({
    super.key,
    required this.label,
    this.tone = MqBadgeTone.neutral,
    this.icon,
    this.solid = false,
  });

  final String label;
  final MqBadgeTone tone;
  final IconData? icon;

  /// Solid filled badge (white text on tone color) vs. soft tinted badge.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;

    final Color base = switch (tone) {
      MqBadgeTone.neutral => mq.ink2,
      MqBadgeTone.accent => mq.accent,
      MqBadgeTone.orange => mq.orange,
      MqBadgeTone.success => mq.success,
      MqBadgeTone.error => mq.error,
    };
    final Color softBg = switch (tone) {
      MqBadgeTone.neutral => mq.fill2,
      MqBadgeTone.accent => mq.accentSoft,
      MqBadgeTone.orange => mq.orangeSoft,
      MqBadgeTone.success => mq.success.withValues(alpha: 0.14),
      MqBadgeTone.error => mq.error.withValues(alpha: 0.14),
    };

    final bg = solid ? base : softBg;
    final fg = solid ? mq.onAccent : base;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.sm, vertical: MqSpacing.xxs),
      decoration: BoxDecoration(color: bg, borderRadius: MqRadius.brPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: MqSpacing.xs),
          ],
          Text(
            label,
            style: context.text.labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
