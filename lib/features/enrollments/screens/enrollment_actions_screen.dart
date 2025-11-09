import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/services/permission_service.dart';
import 'package:mulhimiq/shared/widgets/global_app_bar.dart';
import 'package:mulhimiq/features/enrollments/screens/course_attendance_screen.dart';
import 'package:mulhimiq/features/enrollments/screens/course_weekly_schedule_screen.dart';
import 'package:mulhimiq/features/assignments/screens/student_assignments_screen.dart';
import 'package:mulhimiq/features/exams/screens/student_exams_screen.dart';
import 'package:mulhimiq/features/exams/screens/student_exam_grades_screen.dart';
import 'package:mulhimiq/features/evaluations/screens/student_evaluations_screen.dart';

class EnrollmentActionsScreen extends StatefulWidget {
  final String courseId;
  final String? courseName;
  final String? teacherId;

  const EnrollmentActionsScreen({
    super.key,
    required this.courseId,
    this.courseName,
    this.teacherId,
  });

  @override
  State<EnrollmentActionsScreen> createState() =>
      _EnrollmentActionsScreenState();
}

class _EnrollmentActionsScreenState extends State<EnrollmentActionsScreen> {
  final _api = ApiService();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final actions = [
      _ActionItem(
        icon: Icons.qr_code_scanner,
        color: Colors.indigo,
        title: 'مسح حضور (QR)',
        subtitle: 'استخدم الكاميرا لمسح رمز حضور المعلم',
        onTap: _onScanAttendance,
      ),
      _ActionItem(
        icon: Icons.calendar_month,
        color: Colors.teal,
        title: 'جدول الأسبوع',
        subtitle: 'اعرض جدول الحصص لهذا الكورس',
        onTap: _onOpenWeeklySchedule,
      ),
      _ActionItem(
        icon: Icons.assignment,
        color: Colors.blue,
        title: 'عرض الواجبات',
        subtitle: 'اعرض واجباتك المنزلية',
        onTap: _onOpenAssignments,
      ),
      _ActionItem(
        icon: Icons.fact_check,
        color: Colors.orange,
        title: 'سجل الحضور والغياب',
        subtitle: 'اعرض حضورك وغيابك وإجازاتك',
        onTap: _onOpenAttendance,
      ),
      _ActionItem(
        icon: Icons.today,
        color: Colors.purple,
        title: 'امتحانات يومية',
        subtitle: 'قائمة الامتحانات اليومية',
        onTap: _onOpenDailyExams,
      ),
      _ActionItem(
        icon: Icons.calendar_month_outlined,
        color: Colors.deepPurple,
        title: 'امتحانات شهرية',
        subtitle: 'قائمة الامتحانات الشهرية',
        onTap: _onOpenMonthlyExams,
      ),
      _ActionItem(
        icon: Icons.grade,
        color: Colors.green,
        title: 'الدرجات',
        subtitle: 'عرض درجاتك وتقارير الأداء',
        onTap: _onOpenExamGrades,
      ),
      _ActionItem(
        icon: Icons.star_rate,
        color: Colors.brown,
        title: 'تقييماتي',
        subtitle: 'عرض تقييماتك مع إمكانية التصفية',
        onTap: _onOpenEvaluations,
      ),
      _ActionItem(
        icon: Icons.receipt_long,
        color: Colors.deepOrange,
        title: 'الفواتير والدفعات',
        subtitle: 'عرض فواتير وأقساط هذا الكورس',
        onTap: _onOpenCourseInvoices,
      ),
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: GlobalAppBar(
        title: widget.courseName ?? 'إدارة الدورة',
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            itemCount: actions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, i) {
              final item = actions[i];
              return _buildActionCard(item, cs, isDark);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(_ActionItem item, ColorScheme cs, bool isDark) {
    return InkWell(
      onTap: _busy ? null : item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.surfaceContainerHighest,
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: item.color.withValues(alpha: 0.2),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                item.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
                  color: cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 5),
            Flexible(
              child: Text(
                item.subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: cs.onSurfaceVariant,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ المسارات والعمليات
  void _onOpenWeeklySchedule() {
    if (widget.courseId.isEmpty) {
      _showSnack('لا يمكن فتح الجدول: معرف الكورس مفقود');
      return;
    }
    Get.to(
      () => CourseWeeklyScheduleScreen(
        courseId: widget.courseId,
        courseName: widget.courseName,
      ),
    );
  }

  void _onOpenAttendance() {
    if (widget.courseId.isEmpty) {
      _showSnack('لا يمكن فتح السجل: معرف الكورس مفقود');
      return;
    }
    Get.to(
      () => CourseAttendanceScreen(
        courseId: widget.courseId,
        courseName: widget.courseName,
      ),
    );
  }

  void _onOpenAssignments() {
    Get.to(() => const StudentAssignmentsScreen());
  }

  void _onOpenDailyExams() {
    Get.to(
      () =>
          const StudentExamsScreen(fixedType: 'daily', title: 'امتحانات يومية'),
    );
  }

  void _onOpenMonthlyExams() {
    Get.to(
      () => const StudentExamsScreen(
        fixedType: 'monthly',
        title: 'امتحانات شهرية',
      ),
    );
  }

  void _onOpenExamGrades() {
    Get.to(() => const StudentExamGradesScreen());
  }

  void _onOpenEvaluations() {
    Get.to(() => const StudentEvaluationsScreen());
  }

  void _onOpenCourseInvoices() {
    if (widget.courseId.isEmpty) {
      _showSnack('لا يمكن فتح الفواتير: معرف الكورس مفقود');
      return;
    }
    Get.toNamed(
      '/invoices',
      arguments: {
        'courseId': widget.courseId,
        if (widget.courseName != null) 'courseName': widget.courseName,
      },
    );
  }

  // ✅ مسح الحضور
  Future<void> _onScanAttendance() async {
    final granted = await PermissionService.requestCameraPermission();
    if (!granted) {
      _showSnack('يرجى منح إذن الكاميرا للمتابعة');
      return;
    }

    final teacherId = await Get.toNamed<String?>('/qr-scan');
    if (teacherId == null || teacherId.isEmpty) return;

    setState(() => _busy = true);
    try {
      final res = await _api.checkInAttendance(teacherId: teacherId);
      final success = res['success'] == true;
      final msg = (res['message'] ?? '').toString();
      final data = res['data'] as Map<String, dynamic>?;
      final duplicate = data != null && data['duplicate'] == true;

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            duplicate ? 'مسجل مسبقاً' : (success ? 'تم التسجيل' : 'لم يكتمل'),
          ),
          content: Text(
            msg.isNotEmpty
                ? msg
                : (success ? 'تم تسجيل حضورك بنجاح.' : 'تعذر تسجيل الحضور'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await _showTextOnlySheet(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showTextOnlySheet(String text) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ActionItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _ActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
