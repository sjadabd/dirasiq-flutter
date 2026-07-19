import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../profile/teacher_profile_screen.dart';
import '../video_courses/teacher_video_course_detail_screen.dart';
import 'teacher_workspace.dart';

bool isVideoCourseNotification(String? subType, String? routeOrPath) {
  final s = subType?.toLowerCase() ?? '';
  if (s.startsWith('video_course') || s.startsWith('video_lesson')) return true;
  final r = routeOrPath?.toLowerCase() ?? '';
  return r.contains('/teacher/video-courses');
}

bool isIntroVideoNotification({
  String? type,
  String? dataType,
  String? routeOrPath,
}) {
  final t = (type ?? '').toLowerCase();
  final d = (dataType ?? '').toLowerCase();
  if (t.startsWith('intro_video') || d.startsWith('intro_video')) return true;
  final r = (routeOrPath ?? '').split('?').first.trim().toLowerCase();
  return r == '/teacher/profile' || r.endsWith('/teacher/profile');
}

/// Notification tap → teacher profile (intro-video approve/reject, etc.).
void openTeacherProfileFromNotification(BuildContext context) {
  final inTree = context.findAncestorStateOfType<TeacherWorkspaceState>();
  if (inTree != null || TeacherWorkspaceState.active != null) {
    TeacherWorkspace.jumpTo(context, TeacherWorkspaceState.profileIdx);
    return;
  }
  Get.to(() => const TeacherProfileScreen());
}

/// Notification tap → الدورات المرئية tab, optionally open course detail.
void openTeacherVideoCourseFromNotification(
  BuildContext context, {
  String? courseId,
}) {
  TeacherWorkspace.jumpTo(context, TeacherWorkspaceState.videoCoursesIdx);
  final id = courseId?.trim();
  if (id != null && id.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.to(() => TeacherVideoCourseDetailScreen(courseId: id));
    });
  }
}

/// True only when payload carries attendance/session markers — not notification read status.
bool hasAttendancePayload(Map<String, dynamic> payload) {
  if (payload.containsKey('attendanceStatus') ||
      payload.containsKey('attendance_status')) {
    return true;
  }
  final status = payload['status']?.toString().toLowerCase();
  if (status != null &&
      const {'present', 'absent', 'late', 'excused', 'attended', 'missed'}
          .contains(status)) {
    return true;
  }
  if (payload.containsKey('sessionId') || payload.containsKey('session_id')) {
    return true;
  }
  if (payload.containsKey('date') &&
      (payload.containsKey('courseId') || payload.containsKey('course_id'))) {
    return true;
  }
  return false;
}
