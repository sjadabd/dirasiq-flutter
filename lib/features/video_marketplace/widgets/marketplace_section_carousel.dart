// Video marketplace — titled horizontal carousel (MulhimIQ design system).
//
// A section header + a horizontal row of [VideoCourseCard]s. Used for the
// "مكتبتي" continue-watching row. Renders nothing when the list is empty so
// the screen never grows an empty section.

import 'package:flutter/material.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'video_course_card.dart';

class MarketplaceSectionCarousel extends StatelessWidget {
  const MarketplaceSectionCarousel({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.onTapCourse,
    this.subtitle,
    this.accent,
  });

  final String title;
  final IconData icon;
  final Color? accent;
  final String? subtitle;
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> course) onTapCourse;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final m = context.mq;
    final c = accent ?? m.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.sm),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: MqRadius.brMd),
              child: Icon(icon, size: MqSize.iconSm, color: c),
            ),
            MqSpacing.gapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: context.text.titleSmall),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!, style: context.text.labelSmall),
                ],
              ),
            ),
            MqBadge(label: '${items.length}', tone: MqBadgeTone.neutral),
          ]),
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: MqSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.sm),
            itemBuilder: (_, i) => VideoCourseCard(course: items[i], width: 200, onTap: () => onTapCourse(items[i])),
          ),
        ),
      ],
    );
  }
}
