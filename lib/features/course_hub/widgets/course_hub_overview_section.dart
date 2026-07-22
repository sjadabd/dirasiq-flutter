// Course Hub — Overview section (MulhimIQ design system).
//
// Top card on the Hub: course cover banner + name + teacher chip (tap → teacher
// details) + course-type badge + short description + progress/attendance when
// the backend provides them. Every field is conditionally rendered.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/features/course_hub/controllers/course_hub_controller.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';
import 'package:mulhimiq/features/teachers/screens/teacher_details_screen.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

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
    final mq = context.mq;
    return Obx(() {
      if (_c.overviewLoading.value && _c.overview.value == null) {
        return const CourseHubSectionShell(
          icon: Icons.school_outlined,
          title: 'نظرة عامة',
          child: CourseHubSectionLoading(height: 120),
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
      final cover = _absolute(_firstImagePath(course['course_images'] ?? course['courseImages']));
      final name = (course['courseName'] ?? course['name'] ?? _c.initialCourseName ?? 'الدورة').toString();
      final teacherName = (teacher['name'] ?? '').toString();
      final teacherId = (teacher['id'] ?? '').toString();
      final type = _courseType(course);
      final desc = (course['description'] ?? '').toString().trim();
      final progress = _num(course['progressPercent'] ?? course['attendancePercent'] ?? course['progress']);

      return CourseHubSectionShell(
        icon: Icons.school_outlined,
        title: 'نظرة عامة',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: MqRadius.brMd,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: cover.isEmpty
                    ? Container(color: mq.fill2, alignment: Alignment.center,
                        child: Icon(Icons.image_outlined, size: 36, color: mq.ink3))
                    : Image.network(cover, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: mq.fill2, alignment: Alignment.center,
                            child: Icon(Icons.image_not_supported_outlined, color: mq.ink3))),
              ),
            ),
            MqSpacing.gapMd,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(name, style: context.text.titleMedium)),
                if (_c.isArchiveMode) ...[
                  MqSpacing.gapXs,
                  MqBadge(
                    label: _c.isCourseDeleted ? 'محذوفة' : 'منتهية',
                    tone: MqBadgeTone.orange,
                  ),
                ] else if (type != null) ...[
                  MqSpacing.gapXs,
                  MqBadge(label: type, tone: MqBadgeTone.accent),
                ],
              ],
            ),
            if (teacherName.isNotEmpty) ...[
              MqSpacing.gapSm,
              InkWell(
                onTap: teacherId.isEmpty ? null : () => Get.to(() => TeacherDetailsScreen(teacherId: teacherId)),
                borderRadius: MqRadius.brSm,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline_rounded, size: MqSize.iconSm, color: mq.accent),
                    MqSpacing.gapXs,
                    Text(teacherName, style: context.text.bodyMedium?.copyWith(color: mq.accent, fontWeight: FontWeight.w600)),
                    if (teacherId.isNotEmpty) Icon(Icons.chevron_left_rounded, size: 18, color: mq.accent),
                  ],
                ),
              ),
            ],
            if (desc.isNotEmpty) ...[
              MqSpacing.gapSm,
              Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(height: 1.5)),
            ],
            if (progress != null) ...[
              MqSpacing.gapMd,
              Row(
                children: [
                  Text('تقدّمك في الدورة', style: context.text.labelMedium),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 6),
              MqLinearProgress(value: (progress / 100).clamp(0, 1), showLabel: true),
            ],
          ],
        ),
      );
    });
  }

  double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}');
  }

  String? _courseType(Map<String, dynamic> c) {
    final raw = (c['courseType'] ?? c['course_type'] ?? c['type'] ?? c['delivery'])?.toString().toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    if (raw.contains('video') || raw.contains('مرئي')) return 'مرئي';
    if (raw.contains('live') || raw.contains('مباشر')) return 'مباشر';
    return 'حضوري';
  }

  String _firstImagePath(dynamic raw) {
    if (raw is List && raw.isNotEmpty && raw.first is String) return raw.first as String;
    return '';
  }

  String _absolute(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${AppConfig.serverBaseUrl}$path';
  }
}
