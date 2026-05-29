// Course Hub — Schedule section.
//
// Surfaces the weekly schedule for THIS course in a compact list. Each
// row shows weekday + start-end times. Tapping the section's CTA opens
// the full per-course schedule screen.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/features/course_hub/controllers/course_hub_controller.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';
import 'package:mulhimiq/features/enrollments/screens/course_weekly_schedule_screen.dart';

class CourseHubScheduleSection extends StatefulWidget {
  const CourseHubScheduleSection({super.key});

  @override
  State<CourseHubScheduleSection> createState() => _CourseHubScheduleSectionState();
}

class _CourseHubScheduleSectionState extends State<CourseHubScheduleSection> {
  CourseHubController get _c => Get.find<CourseHubController>();

  static const List<String> _arWeekday = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.ensureSectionLoaded(CourseHubSection.schedule);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Widget body;
      final loading = _c.scheduleLoading.value && _c.scheduleRows.isEmpty;
      final err = _c.scheduleError.value;
      if (loading) {
        body = const CourseHubSectionLoading();
      } else if (err.isNotEmpty && _c.scheduleRows.isEmpty) {
        body = CourseHubSectionError(
          message: err,
          onRetry: () => _c.ensureSectionLoaded(CourseHubSection.schedule),
        );
      } else if (_c.scheduleRows.isEmpty) {
        body = const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('لا يوجد جدول معتمد لهذا الكورس بعد.',
              style: TextStyle(fontSize: 12)),
        );
      } else {
        body = Column(
          children: _c.scheduleRows.take(4).map(_buildSlotRow).toList(),
        );
      }

      return CourseHubSectionShell(
        icon: Icons.calendar_today_outlined,
        title: 'الجدول الأسبوعي',
        action: TextButton(
          onPressed: () => Get.to(() => CourseWeeklyScheduleScreen(
                courseId: _c.courseId,
                courseName: _c.initialCourseName,
              )),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('عرض الكل', style: TextStyle(fontSize: 12)),
        ),
        child: body,
      );
    });
  }

  Widget _buildSlotRow(Map<String, dynamic> slot) {
    final dayIndex = (slot['day_of_week'] ?? slot['dayOfWeek'] ?? 0) as int;
    final start = (slot['start_time'] ?? slot['startTime'] ?? '').toString();
    final end = (slot['end_time'] ?? slot['endTime'] ?? '').toString();
    final dayLabel = (dayIndex >= 0 && dayIndex < _arWeekday.length)
        ? _arWeekday[dayIndex]
        : '—';
    return CourseHubRow(
      icon: Icons.schedule_outlined,
      label: dayLabel,
      subtitle: start.isNotEmpty && end.isNotEmpty ? '$start – $end' : '',
    );
  }
}
