// Course Hub — Attendance section.
//
// Two rows:
//   1. QR check-in (opens the camera flow). Same target as the legacy
//      enrollment-actions tile, so the user's muscle memory carries over.
//   2. Attendance log (opens the per-course attendance screen).
//
// The lazy fetch ensures we can render a "tap to view" hint even when
// the section's data hasn't been pulled yet.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/services/permission_service.dart';
import 'package:mulhimiq/features/course_hub/controllers/course_hub_controller.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';
import 'package:mulhimiq/features/enrollments/screens/course_attendance_screen.dart';
import 'package:mulhimiq/features/qr/qr_scan_screen.dart';

class CourseHubAttendanceSection extends StatefulWidget {
  const CourseHubAttendanceSection({super.key});

  @override
  State<CourseHubAttendanceSection> createState() => _CourseHubAttendanceSectionState();
}

class _CourseHubAttendanceSectionState extends State<CourseHubAttendanceSection> {
  CourseHubController get _c => Get.find<CourseHubController>();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.ensureSectionLoaded(CourseHubSection.attendance);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CourseHubSectionShell(
      icon: Icons.event_available_outlined,
      title: 'الحضور',
      child: Column(
        children: [
          CourseHubRow(
            icon: Icons.qr_code_scanner,
            label: 'تسجيل حضور (QR)',
            subtitle: 'استخدم الكاميرا لمسح رمز الأستاذ',
            onTap: _busy ? null : _onScanAttendance,
          ),
          CourseHubRow(
            icon: Icons.list_alt_outlined,
            label: 'سجل الحضور والغياب',
            subtitle: _attendanceSummary(),
            onTap: () => Get.to(() => CourseAttendanceScreen(
                  courseId: _c.courseId,
                  courseName: _c.initialCourseName,
                )),
          ),
        ],
      ),
    );
  }

  String _attendanceSummary() {
    final data = _c.attendance.value;
    if (data == null) return 'اعرض حضورك وغيابك';
    // Best-effort summary — the endpoint returns a list of sessions.
    final list = data['sessions'] ?? data['records'] ?? data['data'];
    if (list is List && list.isNotEmpty) {
      final present = list
          .where((s) => (s is Map) && (s['status'] == 'present'))
          .length;
      return '$present/${list.length} حضور';
    }
    return 'اعرض حضورك وغيابك';
  }

  Future<void> _onScanAttendance() async {
    if (_c.courseId.isEmpty) return;
    final ok = await PermissionService.requestCameraPermission();
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      // QrScanScreen pops with the teacherId as a plain String.
      final result = await Get.to(() => const QrScanScreen());
      final teacherId = (result is String
              ? result
              : (result is Map ? result['teacherId'] : null))
          ?.toString();
      if (teacherId == null || teacherId.isEmpty) return;
      try {
        await ApiService().checkInAttendance(
          teacherId: teacherId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تسجيل الحضور بنجاح')),
          );
          _c.ensureSectionLoaded(CourseHubSection.attendance);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تسجيل الحضور: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
