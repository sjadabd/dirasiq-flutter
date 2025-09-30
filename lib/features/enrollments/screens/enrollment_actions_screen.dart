import 'package:flutter/material.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:dirasiq/core/services/permission_service.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:get/get.dart';
import 'package:dirasiq/features/enrollments/screens/course_attendance_screen.dart';
import 'package:dirasiq/features/enrollments/screens/course_weekly_schedule_screen.dart';

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
    final title = widget.courseName ?? 'إدارة الدورة';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlobalAppBar(title: title, centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _actionCard(
              icon: Icons.qr_code_scanner,
              title: 'مسح حضور (QR)',
              subtitle: 'استخدم كاميرا الجهاز لمسح رمز حضور المعلم',
              color: Colors.indigo,
              onTap: _onScanAttendance,
            ),
            const SizedBox(height: 12),
            _actionCard(
              icon: Icons.calendar_month,
              title: 'جدول الأسبوع',
              subtitle: 'اعرض جدول الحصص لهذا الكورس',
              color: Colors.teal,
              onTap: _onOpenWeeklySchedule,
            ),
            const SizedBox(height: 12),
            _actionCard(
              icon: Icons.fact_check,
              title: 'سجل الحضور والغياب',
              subtitle: 'اعرض حضورك وغيابك وإجازاتك لهذا الكورس',
              color: Colors.orange,
              onTap: _onOpenAttendance,
            ),
          ],
        ),
      ),
    );
  }

  void _onOpenWeeklySchedule() {
    if (widget.courseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن فتح الجدول: معرف الكورس مفقود')),
      );
      return;
    }
    Get.to(() => CourseWeeklyScheduleScreen(
          courseId: widget.courseId,
          courseName: widget.courseName,
        ));
  }

  void _onOpenAttendance() {
    if (widget.courseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن فتح السجل: معرف الكورس مفقود')),
      );
      return;
    }
    Get.to(() => CourseAttendanceScreen(
          courseId: widget.courseId,
          courseName: widget.courseName,
        ));
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_left),
        onTap: _busy ? null : onTap,
      ),
    );
  }

  Future<void> _onScanAttendance() async {
    final granted = await PermissionService.requestCameraPermission();
    if (!granted) {
      _showSnack('يرجى منح إذن الكاميرا للمتابعة');
      return;
    }

    final teacherId = await Navigator.pushNamed(context, '/qr-scan') as String?;
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
      // ✅ هنا نعرض رسالة السيرفر فقط
      String message = e.toString().replaceAll("Exception: ", "");
      await _showTextOnlySheet(message);
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
      builder: (_) => SingleChildScrollView(
        // ✅ منع overflow
        child: Padding(
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
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
