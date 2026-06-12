// Phase 6 — Unified Course Hub screen.
//
// One vertical-scroll page composed of 8 self-contained section
// widgets, each owning its own lazy fetch lifecycle. The screen itself
// only wires the GetX controller + the pull-to-refresh.
//
// Replacement for the legacy EnrollmentActionsScreen 8-action grid.
// The legacy screen + route stay in place; the feature flag
// `AppConfig.useNewCourseHub` decides which one navigation runs at the
// entry points. This screen never deletes anything — additions only.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/features/course_hub/controllers/course_hub_controller.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_academic_section.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_announcements_section.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_attendance_section.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_billing_section.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_materials_section.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_other_teacher_courses_section.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_overview_section.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_schedule_section.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_videos_section.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class CourseHubScreen extends StatefulWidget {
  const CourseHubScreen({
    super.key,
    required this.courseId,
    this.courseName,
    this.teacherId,
  });

  final String courseId;
  final String? courseName;
  final String? teacherId;

  @override
  State<CourseHubScreen> createState() => _CourseHubScreenState();
}

class _CourseHubScreenState extends State<CourseHubScreen> {
  late final CourseHubController _controller;

  @override
  void initState() {
    super.initState();
    // Untagged registration. Section widgets call Get.find<>() without
    // a tag, so the lookup must match. Tagging by courseId was the
    // original Phase 6 intent, but it surfaced a "controller not found"
    // crash the moment the flag flipped — sections were never reached
    // while the flag was off. Untagged is safe here because CourseHub
    // is a single fullscreen route: only one instance can be live at a
    // time. dispose() removes the binding on pop so a re-entry to a
    // DIFFERENT course gets a fresh controller with the right courseId.
    _controller = Get.put(
      CourseHubController(
        courseId: widget.courseId,
        initialCourseName: widget.courseName,
        teacherId: widget.teacherId,
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<CourseHubController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();

    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.mq.page,
            appBar: AppBar(
              title: Text(
                widget.courseName ?? 'بيئة الدورة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                // Preserves the old app bar's notifications entry point
                // (course announcements arrive via the notifications feed).
                IconButton(
                  tooltip: 'الإشعارات',
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Get.toNamed('/notifications'),
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _controller.refreshAll,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxxl),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    CourseHubOverviewSection(),
                    CourseHubAnnouncementsSection(),
                    CourseHubAcademicSection(),
                    CourseHubAttendanceSection(),
                    CourseHubScheduleSection(),
                    CourseHubMaterialsSection(),
                    CourseHubVideosSection(),
                    CourseHubBillingSection(),
                    // Discovery tail — same teacher's other catalog. Self-hides
                    // when empty so the hub stays clean for single-course teachers.
                    CourseHubOtherTeacherCoursesSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
