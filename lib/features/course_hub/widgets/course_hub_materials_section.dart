// Course Hub — Learning Materials section.
//
// Phase 6 MVP: the backend does not yet expose a per-course materials
// endpoint. We render a tasteful "soon" placeholder so the section's
// place in the Hub is reserved and the student knows the path.
//
// Phase 8+ will replace the body with a real material list once
// /api/student/courses/:id/materials lands.

import 'package:flutter/material.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';

class CourseHubMaterialsSection extends StatelessWidget {
  const CourseHubMaterialsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CourseHubSectionShell(
      icon: Icons.folder_open_outlined,
      iconColor: Colors.brown,
      title: 'المواد التعليمية',
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الملفات والمرفقات قريباً — سيمكنك الاطّلاع على الملفات التي يشاركها أستاذك مع الدورة.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
