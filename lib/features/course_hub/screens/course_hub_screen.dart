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
import 'package:mulhimiq/shared/widgets/global_app_bar.dart';

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
    // Tag the GetX instance by courseId so re-entering the SAME hub
    // (deep-link, back-from-detail, etc.) reuses the cached sections,
    // while jumping to a DIFFERENT course gets a fresh controller.
    _controller = Get.put(
      CourseHubController(
        courseId: widget.courseId,
        initialCourseName: widget.courseName,
        teacherId: widget.teacherId,
      ),
      tag: widget.courseId,
    );
  }

  @override
  void dispose() {
    Get.delete<CourseHubController>(tag: widget.courseId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(
        title: widget.courseName ?? 'بيئة الدورة',
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _controller.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
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
    );
  }
}
