import 'package:flutter/material.dart';

import '../mq_spacing.dart';
import '../mq_theme.dart';
import '../mq_typography.dart';
import 'mq_card.dart';

/// A single metric figure (`92%`, `4.9`, `+50`, `78`) rendered with IBM Plex
/// Mono numerals over a muted caption — the stat treatment from the export.
class MqStat extends StatelessWidget {
  const MqStat({
    super.key,
    required this.value,
    required this.caption,
    this.icon,
    this.tone = MqStatTone.ink,
  });

  final String value;
  final String caption;
  final IconData? icon;
  final MqStatTone tone;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final valueColor = switch (tone) {
      MqStatTone.ink => mq.ink,
      MqStatTone.accent => mq.accent,
      MqStatTone.orange => mq.orange,
      MqStatTone.success => mq.success,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: MqSize.iconMd, color: valueColor),
          MqSpacing.gapXs,
        ],
        Text(value,
            style: MqTypography.mono(
                color: valueColor, size: 22, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(caption,
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(color: mq.ink2)),
      ],
    );
  }
}

enum MqStatTone { ink, accent, orange, success }

/// The warm "achievement / streak" card — `سلسلة ١٢ يوماً!`. Soft orange wash,
/// orange border, leading icon, headline + supporting line, optional trailing.
class MqAchievementCard extends StatelessWidget {
  const MqAchievementCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.local_fire_department_rounded,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;

    return MqSurface(
      tone: MqSurfaceTone.orange,
      padding: const EdgeInsets.all(MqSpacing.lg),
      borderRadius: MqRadius.brLg,
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: mq.orange,
              borderRadius: MqRadius.brMd,
            ),
            child: Icon(icon, color: mq.onAccent, size: MqSize.iconLg),
          ),
          MqSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: context.text.titleSmall
                        ?.copyWith(color: mq.orangeDeep)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style:
                          context.text.bodySmall?.copyWith(color: mq.ink2)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[MqSpacing.gapSm, trailing!],
        ],
      ),
    );
  }
}
