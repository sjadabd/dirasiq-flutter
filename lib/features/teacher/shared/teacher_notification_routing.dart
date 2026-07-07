import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../video_courses/teacher_video_course_detail_screen.dart';
import 'teacher_workspace.dart';

bool isVideoCourseNotification(String? subType, String? routeOrPath) {
  final s = subType?.toLowerCase() ?? '';
  if (s.startsWith('video_course') || s.startsWith('video_lesson')) return true;
  final r = routeOrPath?.toLowerCase() ?? '';
  return r.contains('/teacher/video-courses');
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
