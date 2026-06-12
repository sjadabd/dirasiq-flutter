// Course Hub — Announcements section (MulhimIQ design system).
//
// Phase 6 MVP: no per-course feed yet (the backend doesn't expose one). The
// section keeps a single, supported CTA that opens the global notifications
// screen — course announcements arrive there today. The action is always
// relevant, so the section stays visible.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class CourseHubAnnouncementsSection extends StatelessWidget {
  const CourseHubAnnouncementsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseHubSectionShell(
      icon: Icons.campaign_outlined,
      iconColor: context.mq.orange,
      title: 'الإعلانات',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'إعلانات الدورة تصلك ضمن إشعاراتك. افتح الإشعارات للاطّلاع على آخرها.',
            style: context.text.bodySmall,
          ),
          MqSpacing.gapMd,
          MqButton(
            label: 'فتح الإشعارات',
            icon: Icons.notifications_outlined,
            onPressed: () => Get.toNamed('/notifications'),
          ),
        ],
      ),
    );
  }
}
