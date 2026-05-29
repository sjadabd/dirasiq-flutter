// Course Hub — Announcements section.
//
// Phase 6 MVP: this section does not own a per-course filter (the
// backend doesn't expose one yet). It surfaces a single CTA that opens
// the global notifications screen — same behaviour the existing app
// bar's bell icon offers, but with explicit copy that reminds the
// student that course-level announcements live alongside system
// notifications today.
//
// Phase 8+ will replace the body with a real per-course feed when the
// backend exposes /api/student/courses/:id/announcements.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';

class CourseHubAnnouncementsSection extends StatelessWidget {
  const CourseHubAnnouncementsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CourseHubSectionShell(
      icon: Icons.campaign_outlined,
      iconColor: cs.tertiary,
      title: 'الإعلانات',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'إعلانات الدورة تصلك ضمن إشعاراتك. افتح الإشعارات للاطلاع على آخرها.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => Get.toNamed('/notifications'),
            icon: const Icon(Icons.notifications_outlined, size: 18),
            label: const Text('فتح الإشعارات'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
          ),
        ],
      ),
    );
  }
}
