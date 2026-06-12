import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';

/// Teacher → "رمز الحضور".
///
/// Shows the teacher's attendance QR so students can scan it (their app opens
/// the camera → marks attendance). The QR is generated ON-DEVICE from the
/// teacher's id — encoding `mulhimiq://attend?teacher=<id>`, the exact scheme
/// the student scanner expects — so it renders even with **no internet**.
class TeacherAttendanceQrScreen extends StatefulWidget {
  const TeacherAttendanceQrScreen({super.key});

  @override
  State<TeacherAttendanceQrScreen> createState() =>
      _TeacherAttendanceQrScreenState();
}

class _TeacherAttendanceQrScreenState extends State<TeacherAttendanceQrScreen> {
  String? _teacherId;
  String _teacherName = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user');
      if (raw != null) {
        final u = jsonDecode(raw) as Map<String, dynamic>;
        _teacherId = (u['id'] ?? u['_id'])?.toString();
        _teacherName = (u['name'] ?? '').toString();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String get _payload => 'mulhimiq://attend?teacher=$_teacherId';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          return Scaffold(
            backgroundColor: mq.page,
            appBar: const TeacherAppBar(title: 'رمز الحضور'),
            drawer: const TeacherDrawer(),
            body: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : (_teacherId == null || _teacherId!.isEmpty)
                    ? _error(context)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(MqSpacing.lg,
                            MqSpacing.lg, MqSpacing.lg, MqSpacing.xl),
                        children: [
                          _hero(context),
                          const SizedBox(height: MqSpacing.lg),
                          _qrCard(context),
                          const SizedBox(height: MqSpacing.lg),
                          _instructions(context),
                        ],
                      ),
          );
        }),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final t = context.teacher;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.heroA, t.heroB],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: MqRadius.brXl,
        boxShadow: t.shadowLg,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration:
                BoxDecoration(color: context.mq.orange, shape: BoxShape.circle),
            child: const Icon(Icons.qr_code_2_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('رمز الحضور',
                    style:
                        context.text.titleMedium?.copyWith(color: t.heroInk)),
                const SizedBox(height: 2),
                Text(
                    _teacherName.isEmpty
                        ? 'اعرض الرمز للطلاب لتسجيل حضورهم'
                        : _teacherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        context.text.labelSmall?.copyWith(color: t.heroInk2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrCard(BuildContext context) {
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.xl),
      child: Column(
        children: [
          // QR always on a white surface with dark modules so any camera reads
          // it reliably regardless of the app theme.
          Container(
            padding: const EdgeInsets.all(MqSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: MqRadius.brLg,
              border: Border.all(color: const Color(0xFFE5E9F0)),
            ),
            child: QrImageView(
              data: _payload,
              version: QrVersions.auto,
              size: 240,
              gapless: true,
              eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square, color: Color(0xFF0F2C5C)),
              dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F2C5C)),
            ),
          ),
          const SizedBox(height: MqSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 14, color: context.mq.ink3),
              const SizedBox(width: 4),
              Text('يعمل بدون إنترنت',
                  style:
                      context.text.labelSmall?.copyWith(color: context.mq.ink3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _instructions(BuildContext context) {
    final mq = context.mq;
    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        color: mq.accentSoft,
        borderRadius: MqRadius.brLg,
        border: Border.all(color: mq.accentLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: mq.accent, size: MqSize.iconSm),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Text(
              'اعرض هذا الرمز لطلابك في الحصة. يفتح الطالب تطبيقه ويمسح الرمز '
              'ليُسجَّل حضوره تلقائياً. الرمز ثابت لحسابك ويصلح لكل الحصص.',
              style:
                  context.text.bodySmall?.copyWith(color: mq.ink2, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _error(BuildContext context) {
    final mq = context.mq;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MqSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2_rounded, size: 48, color: mq.ink3),
            const SizedBox(height: MqSpacing.md),
            Text('تعذّر تحميل رمز الحضور — أعد تسجيل الدخول',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: mq.ink2)),
          ],
        ),
      ),
    );
  }
}
