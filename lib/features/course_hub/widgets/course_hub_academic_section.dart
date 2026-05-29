// Course Hub — Academic section.
//
// Three quick-glance rows: Assignments, Exams, Evaluations / Grades.
// Each one shows a count badge + opens the existing global screen.
// Counts come from the controller's `academic` summary (limit=5 fetch
// + pagination total).

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/features/assignments/screens/student_assignments_screen.dart';
import 'package:mulhimiq/features/course_hub/controllers/course_hub_controller.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';
import 'package:mulhimiq/features/evaluations/screens/student_evaluations_screen.dart';
import 'package:mulhimiq/features/exams/screens/student_exam_grades_screen.dart';
import 'package:mulhimiq/features/exams/screens/student_exams_screen.dart';

class CourseHubAcademicSection extends StatefulWidget {
  const CourseHubAcademicSection({super.key});

  @override
  State<CourseHubAcademicSection> createState() => _CourseHubAcademicSectionState();
}

class _CourseHubAcademicSectionState extends State<CourseHubAcademicSection> {
  CourseHubController get _c => Get.find<CourseHubController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.ensureSectionLoaded(CourseHubSection.academic);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Widget body;
      if (_c.academicLoading.value && _c.academic.value == null) {
        body = const CourseHubSectionLoading(height: 60);
      } else if (_c.academicError.value.isNotEmpty && _c.academic.value == null) {
        body = CourseHubSectionError(
          message: _c.academicError.value,
          onRetry: () => _c.ensureSectionLoaded(CourseHubSection.academic),
        );
      } else {
        body = Column(
          children: [
            CourseHubRow(
              icon: Icons.assignment_outlined,
              label: 'الواجبات',
              subtitle: _c.assignmentsCount > 0
                  ? 'لديك ${_c.assignmentsCount} واجب'
                  : 'لا توجد واجبات حالياً',
              trailing: _c.assignmentsCount > 0
                  ? CourseHubBadge(label: '${_c.assignmentsCount}')
                  : null,
              onTap: () => Get.to(() => const StudentAssignmentsScreen()),
            ),
            CourseHubRow(
              icon: Icons.fact_check_outlined,
              label: 'الامتحانات',
              subtitle: _c.upcomingExamsCount > 0
                  ? '${_c.upcomingExamsCount} امتحان قادم'
                  : 'لا توجد امتحانات قادمة',
              trailing: _c.upcomingExamsCount > 0
                  ? CourseHubBadge(label: '${_c.upcomingExamsCount}', color: Colors.deepOrange)
                  : null,
              onTap: () => Get.to(() => const StudentExamsScreen(
                    fixedType: 'daily',
                    title: 'الامتحانات اليومية',
                  )),
            ),
            CourseHubRow(
              icon: Icons.grade_outlined,
              label: 'الدرجات والتقارير',
              subtitle: 'اعرض درجاتك في الامتحانات',
              onTap: () => Get.to(() => const StudentExamGradesScreen()),
            ),
            CourseHubRow(
              icon: Icons.star_border_outlined,
              label: 'تقييمات الأستاذ',
              subtitle: 'تقييم أدائك من الأستاذ',
              onTap: () => Get.to(() => const StudentEvaluationsScreen()),
            ),
          ],
        );
      }
      return CourseHubSectionShell(
        icon: Icons.book_outlined,
        title: 'الأكاديمي',
        child: body,
      );
    });
  }
}
