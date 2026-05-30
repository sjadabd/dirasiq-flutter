// Course Hub — Overview section.
//
// Top card on the Hub. Shows course name + teacher + the first cover
// image and three quick-glance pills (attendance %, pending count,
// next session). Tapping the teacher chip opens the teacher details
// screen.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/features/course_hub/controllers/course_hub_controller.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';
import 'package:mulhimiq/features/teachers/screens/teacher_details_screen.dart';

class CourseHubOverviewSection extends StatefulWidget {
  const CourseHubOverviewSection({super.key});

  @override
  State<CourseHubOverviewSection> createState() => _CourseHubOverviewSectionState();
}

class _CourseHubOverviewSectionState extends State<CourseHubOverviewSection> {
  CourseHubController get _c => Get.find<CourseHubController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.ensureSectionLoaded(CourseHubSection.overview);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      if (_c.overviewLoading.value && _c.overview.value == null) {
        return const CourseHubSectionShell(
          icon: Icons.school_outlined,
          title: 'نظرة عامة',
          child: CourseHubSectionLoading(height: 80),
        );
      }
      if (_c.overviewError.value.isNotEmpty && _c.overview.value == null) {
        return CourseHubSectionShell(
          icon: Icons.school_outlined,
          title: 'نظرة عامة',
          child: CourseHubSectionError(
            message: _c.overviewError.value,
            onRetry: () => _c.ensureSectionLoaded(CourseHubSection.overview),
          ),
        );
      }
      final ov = _c.overview.value ?? {};
      final course = ov['course'] is Map ? Map<String, dynamic>.from(ov['course']) : ov;
      final teacher = course['teacher'] is Map ? Map<String, dynamic>.from(course['teacher']) : <String, dynamic>{};
      final coverPath = _firstImagePath(course['course_images'] ?? course['courseImages']);
      final fullCover = _absolute(coverPath);

      return CourseHubSectionShell(
        icon: Icons.school_outlined,
        title: 'نظرة عامة',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fullCover.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    fullCover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: cs.surfaceContainerLow,
                      child: Icon(Icons.image_not_supported_outlined,
                          color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              (course['courseName'] ?? course['name'] ?? _c.initialCourseName ?? 'الدورة').toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            if (teacher.isNotEmpty)
              InkWell(
                onTap: () {
                  final id = (teacher['id'] ?? '').toString();
                  if (id.isNotEmpty) {
                    Get.to(() => TeacherDetailsScreen(teacherId: id));
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      (teacher['name'] ?? '').toString(),
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_left, size: 16, color: cs.primary),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if ((course['description'] ?? '').toString().isNotEmpty)
              Text(
                course['description'].toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
          ],
        ),
      );
    });
  }

  String _firstImagePath(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is String) return first;
    }
    return '';
  }

  String _absolute(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${AppConfig.serverBaseUrl}$path';
  }
}
