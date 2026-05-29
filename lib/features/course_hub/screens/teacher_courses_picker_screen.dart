// Phase 6 — Teacher → Courses picker.
//
// Surfaces when the student taps a teacher card on the "My Teachers"
// home tab AND that teacher has MORE THAN ONE shared course. The user
// picks one and lands on the Course Hub for it. Single-course teachers
// skip this screen and go straight to the Hub (handled at the caller).
//
// The list of courses is passed in by the caller — same shape as the
// enrollment row that produced it. We do not refetch.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/features/course_hub/screens/course_hub_screen.dart';
import 'package:mulhimiq/shared/widgets/global_app_bar.dart';

class TeacherCoursesPickerScreen extends StatelessWidget {
  const TeacherCoursesPickerScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.courses,
  });

  /// Caller-provided teacher id (forwarded into the Course Hub so the
  /// Overview section can deep-link to the teacher details screen).
  final String teacherId;

  /// Shown in the app bar.
  final String teacherName;

  /// Courses the student shares with this teacher. Each entry must
  /// carry `id` + `name` (other keys are ignored). Order is preserved.
  final List<Map<String, dynamic>> courses;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GlobalAppBar(
        title: teacherName,
        centerTitle: true,
      ),
      body: SafeArea(
        child: courses.isEmpty
            ? _buildEmpty(cs)
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: courses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final c = courses[i];
                  return _buildCourseCard(c, cs);
                },
              ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'لا توجد دورات مشتركة مع هذا الأستاذ.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, ColorScheme cs) {
    final courseId = (course['id'] ?? '').toString();
    final courseName = (course['name'] ?? 'دورة').toString();
    final status = (course['status'] ?? '').toString();

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: courseId.isEmpty
            ? null
            : () => Get.off(() => CourseHubScreen(
                  courseId: courseId,
                  courseName: courseName,
                  teacherId: teacherId,
                )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primary.withValues(alpha: 0.15),
                child: Icon(Icons.school, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'الحالة: $status',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
