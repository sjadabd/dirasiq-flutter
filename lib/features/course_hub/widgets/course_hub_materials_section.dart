// Course Hub — Learning Materials section (MulhimIQ design system).
//
// The backend does not yet expose a per-course materials endpoint
// (no /api/student/courses/:id/materials route, controller, or API method
// exists today). Rather than fabricate file rows, this section renders an
// honest "coming soon" empty state, restyled with the design-system tokens so
// it stays consistent with every other Course Hub section. When the materials
// endpoint lands, replace the body with the real list — the surrounding shell
// (icon + title) stays the same.

import 'package:flutter/material.dart';

import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class CourseHubMaterialsSection extends StatelessWidget {
  const CourseHubMaterialsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return CourseHubSectionShell(
      icon: Icons.folder_open_outlined,
      iconColor: mq.orange,
      title: 'المواد التعليمية',
      badge: const _SoonBadge(),
      child: MqSurface(
        tone: MqSurfaceTone.neutral,
        padding: const EdgeInsets.symmetric(
            vertical: MqSpacing.xl, horizontal: MqSpacing.lg),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(MqSpacing.md),
              decoration:
                  BoxDecoration(color: mq.orangeSoft, shape: BoxShape.circle),
              child: Icon(Icons.folder_open_outlined,
                  size: 34, color: mq.orange),
            ),
            MqSpacing.gapSm,
            Text('ملفات ومحاضرات ومصادر الدورة',
                style: context.text.titleSmall, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'سيمكنك الاطّلاع هنا على الملفات والمرفقات التي يشاركها أستاذك مع الدورة قريباً.',
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return const MqBadge(
      label: 'قريباً',
      tone: MqBadgeTone.orange,
      icon: Icons.schedule_rounded,
    );
  }
}
