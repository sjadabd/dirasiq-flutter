import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../../../core/utils/time_format.dart';
import '../sessions/teacher_attendance_screen.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_helpers.dart' show initialsOf;
import 'teacher_assignment_detail_screen.dart';
import 'teacher_assignment_form.dart';
import 'teacher_evaluation_form.dart';
import 'teacher_exam_detail_screen.dart';
import 'teacher_exam_form.dart';
import 'teacher_student_detail_screen.dart';

/// Teacher → "إدارة الدورة" — matched to ادارة_الدورة_Light/Dark.html.
///
/// Header + bottom nav follow the shared teacher chrome. Tabs:
///   • نظرة عامة — real student/session counts + quick actions; performance
///     charts / submissions are honest empty states (no teacher endpoint).
///   • الطلاب   — real list (`fetchStudentsByCourse`).
///   • الحضور   — real sessions (`fetchSessions(courseId)`) → attendance screen.
///   • الواجبات / الاختبارات / الدرجات — honest empty states; the teacher app
///     has no assignment/exam/grade endpoints yet (TODO(backend)).
class TeacherCourseManageScreen extends StatefulWidget {
  const TeacherCourseManageScreen({
    super.key,
    required this.courseId,
    required this.course,
    this.initialTab = 0,
  });

  final String courseId;
  final Map<String, dynamic> course;
  final int initialTab;

  @override
  State<TeacherCourseManageScreen> createState() =>
      _TeacherCourseManageScreenState();
}

class _TeacherCourseManageScreenState extends State<TeacherCourseManageScreen> {
  final _api = TeacherApiService();

  int _tab = 0;
  bool _loading = false;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _exams = [];

  // Evaluations tab (loaded lazily, per selected date).
  DateTime _evalDate = DateTime.now();
  List<Map<String, dynamic>> _evalStudents = [];
  bool _evalLoading = false;
  bool _evalLoaded = false;
  bool _evalError = false;

  static const _tabs = [
    'نظرة عامة',
    'الطلاب',
    'الحضور',
    'الواجبات',
    'الاختبارات',
    'التقييمات',
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.fetchStudentsByCourse(widget.courseId),
        _api.fetchSessions(courseId: widget.courseId, page: 1, limit: 100),
        _api.fetchAssignments(page: 1, limit: 100),
        _api.fetchExams(page: 1, limit: 100),
      ]);
      _students = _list(results[0]);
      _sessions = _list(results[1]);
      _assignments = _list(results[2])
          .where((a) => (a['course_id'] ?? '').toString() == widget.courseId)
          .toList();
      _exams = _list(results[3])
          .where((e) => (e['course_id'] ?? '').toString() == widget.courseId)
          .toList();
    } catch (_) {
      Get.snackbar(
        'خطأ',
        'تعذّر تحميل بيانات الدورة',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> res) {
    final d = res['data'];
    if (d is List) {
      return d
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    if (d is Map && d['items'] is List) {
      return (d['items'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }

  bool get _isEnded {
    final end = DateTime.tryParse((widget.course['end_date'] ?? '').toString());
    return end != null && end.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            final mq = context.mq;
            return Scaffold(
              backgroundColor: mq.page,
              appBar: const TeacherAppBar(title: 'إدارة الدورة'),
              body: RefreshIndicator(
                onRefresh: _load,
                color: mq.accent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    MqSpacing.lg,
                    MqSpacing.lg,
                    MqSpacing.lg,
                    MqSpacing.xl,
                  ),
                  children: [
                    _headerCard(context),
                    const SizedBox(height: MqSpacing.md),
                    _tabBar(context),
                    const SizedBox(height: MqSpacing.md),
                    if (_loading && _students.isEmpty && _sessions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(MqSpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      ..._tabBody(context),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---- header ---------------------------------------------------------------

  Widget _headerCard(BuildContext context) {
    final t = context.teacher;
    final c = widget.course;
    final title = (c['course_name'] ?? 'الدورة').toString();
    final subject = (c['subject_name'] ?? '').toString();
    final grade = (c['grade_name'] ?? '').toString();
    final meta = [subject, grade].where((s) => s.isNotEmpty).join(' · ');

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.text.titleMedium?.copyWith(color: t.heroInk),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MqSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: t.heroTile,
                  borderRadius: MqRadius.brPill,
                  border: Border.all(color: t.heroLine),
                ),
                child: Text(
                  _isEnded ? 'منتهية' : 'نشطة',
                  style: context.text.labelSmall?.copyWith(color: t.heroInk),
                ),
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              meta,
              style: context.text.labelSmall?.copyWith(color: t.heroInk2),
            ),
          ],
          const SizedBox(height: MqSpacing.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heroStat('${_students.length}', 'الطلاب'),
                const SizedBox(width: MqSpacing.sm),
                _heroStat('${_sessions.length}', 'الحصص'),
                const SizedBox(width: MqSpacing.sm),
                _heroStat('${c['seats_count'] ?? 0}', 'المقاعد'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Expanded(
      child: Builder(
        builder: (context) {
          final t = context.teacher;
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MqSpacing.sm,
              vertical: MqSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: t.heroTile,
              borderRadius: MqRadius.brMd,
              border: Border.all(color: t.heroLine),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: MqTypography.mono(
                    color: t.heroInk,
                    size: 18,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: context.text.labelSmall?.copyWith(color: t.heroInk2),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- tab bar --------------------------------------------------------------

  Widget _tabBar(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.sm),
        itemBuilder: (_, i) => MqChip(
          label: _tabs[i],
          selected: _tab == i,
          onTap: () => setState(() => _tab = i),
        ),
      ),
    );
  }

  // ---- tab bodies -----------------------------------------------------------

  List<Widget> _tabBody(BuildContext context) {
    switch (_tab) {
      case 1:
        return _studentsTab(context);
      case 2:
        return _attendanceTab(context);
      case 3:
        return _assignmentsTab(context);
      case 4:
        return _examsTab(context);
      case 5:
        return _evaluationsTab(context);
      default:
        return _overviewTab(context);
    }
  }

  // -- نظرة عامة --
  List<Widget> _overviewTab(BuildContext context) {
    final mq = context.mq;
    return [
      TeacherDashboardCard(
        title: 'إجراءات سريعة',
        icon: Icons.bolt_outlined,
        tone: TeacherTone.warning,
        child: Row(
          children: [
            _QuickAction(
              icon: Icons.fact_check_outlined,
              label: 'الحضور',
              tone: TeacherTone.info,
              onTap: () => setState(() => _tab = 2),
            ),
            _QuickAction(
              icon: Icons.group_outlined,
              label: 'الطلاب',
              tone: TeacherTone.success,
              onTap: () => setState(() => _tab = 1),
            ),
            _QuickAction(
              icon: Icons.campaign_outlined,
              label: 'إعلان',
              tone: TeacherTone.warning,
              onTap: () => Get.toNamed('/notifications'),
            ),
          ],
        ),
      ),
      const SizedBox(height: MqSpacing.md),
      TeacherDashboardCard(
        title: 'مؤشّرات الكورس',
        subtitle: 'ملخّص عام',
        icon: Icons.insights_outlined,
        tone: TeacherTone.info,
        child: Column(
          children: [
            Row(
              children: [
                _statTile(
                  context,
                  'الطلاب',
                  '${_students.length}',
                  Icons.group_outlined,
                  mq.success,
                ),
                const SizedBox(width: MqSpacing.sm),
                _statTile(
                  context,
                  'الحصص',
                  '${_sessions.length}',
                  Icons.event_note_outlined,
                  mq.accent,
                ),
              ],
            ),
            const SizedBox(height: MqSpacing.sm),
            Row(
              children: [
                _statTile(
                  context,
                  'الواجبات',
                  '${_assignments.length}',
                  Icons.assignment_outlined,
                  mq.orange,
                ),
                const SizedBox(width: MqSpacing.sm),
                _statTile(
                  context,
                  'الاختبارات',
                  '${_exams.length}',
                  Icons.quiz_outlined,
                  mq.error,
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _statTile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(MqSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: MqRadius.brMd,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: MqSize.iconMd),
            const SizedBox(height: MqSpacing.xs),
            Text(
              value,
              style: context.text.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: context.text.labelSmall?.copyWith(color: context.mq.ink2),
            ),
          ],
        ),
      ),
    );
  }

  // -- الطلاب --
  List<Widget> _studentsTab(BuildContext context) {
    if (_students.isEmpty) {
      return [
        _emptyCard(
          context,
          'لا يوجد طلاب في هذه الدورة بعد',
          Icons.group_outlined,
        ),
      ];
    }
    return [
      for (final s in _students)
        Padding(
          padding: const EdgeInsets.only(bottom: MqSpacing.sm),
          child: _StudentRow(student: s, onTap: () => _openStudentDetail(s)),
        ),
    ];
  }

  void _openStudentDetail(Map<String, dynamic> s) {
    final id = (s['student_id'] ?? s['id'] ?? '').toString();
    if (id.isEmpty) return;
    Get.to(
      () => TeacherStudentDetailScreen(
        studentId: id,
        studentName: (s['student_name'] ?? s['name'] ?? '—').toString(),
        courseId: widget.courseId,
        assignments: _assignments,
        exams: _exams,
      ),
    );
  }

  // -- الحضور (sessions) --
  List<Widget> _attendanceTab(BuildContext context) {
    if (_sessions.isEmpty) {
      return [
        _emptyCard(
          context,
          'لا توجد حصص لهذه الدورة بعد',
          Icons.event_busy_outlined,
        ),
      ];
    }
    return [
      for (final s in _sessions)
        Padding(
          padding: const EdgeInsets.only(bottom: MqSpacing.sm),
          child: _SessionRow(
            session: s,
            onTap: () => Get.to(
              () => TeacherAttendanceScreen(
                sessionId: s['id'].toString(),
                session: s,
              ),
            ),
          ),
        ),
    ];
  }

  // -- الواجبات --
  List<Widget> _assignmentsTab(BuildContext context) {
    return [
      Row(
        children: [
          Expanded(
            child: Text('واجبات الدورة', style: context.text.titleSmall),
          ),
          MqButton.tonal(
            label: 'إضافة واجب',
            icon: Icons.add_rounded,
            size: MqButtonSize.small,
            expand: false,
            onPressed: _openAddAssignment,
          ),
        ],
      ),
      const SizedBox(height: MqSpacing.md),
      if (_assignments.isEmpty)
        _emptyCard(
          context,
          'لا توجد واجبات لهذه الدورة بعد',
          Icons.assignment_outlined,
        )
      else
        for (final a in _assignments)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.sm),
            child: _AssignmentRow(
              assignment: a,
              onTap: () => _openAssignmentDetail(a),
            ),
          ),
    ];
  }

  Future<void> _openAddAssignment() async {
    final created = await showAssignmentForm(
      context: context,
      courseId: widget.courseId,
      api: _api,
    );
    if (created == true) _load();
  }

  Future<void> _openAssignmentDetail(Map<String, dynamic> a) async {
    final changed = await Get.to<bool>(
      () => TeacherAssignmentDetailScreen(
        assignmentId: a['id'].toString(),
        courseId: widget.courseId,
        assignment: a,
      ),
    );
    if (changed == true) _load();
  }

  // -- الاختبارات --
  List<Widget> _examsTab(BuildContext context) {
    return [
      Row(
        children: [
          Expanded(
            child: Text('اختبارات الدورة', style: context.text.titleSmall),
          ),
          MqButton.tonal(
            label: 'إضافة اختبار',
            icon: Icons.add_rounded,
            size: MqButtonSize.small,
            expand: false,
            onPressed: _openAddExam,
          ),
        ],
      ),
      const SizedBox(height: MqSpacing.md),
      if (_exams.isEmpty)
        _emptyCard(
          context,
          'لا توجد اختبارات لهذه الدورة بعد',
          Icons.quiz_outlined,
        )
      else
        for (final e in _exams)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.sm),
            child: _ExamRow(exam: e, onTap: () => _openExamDetail(e)),
          ),
    ];
  }

  Future<void> _openAddExam() async {
    final created = await showExamForm(
      context: context,
      courseId: widget.courseId,
      api: _api,
    );
    if (created == true) _load();
  }

  Future<void> _openExamDetail(Map<String, dynamic> e) async {
    final changed = await Get.to<bool>(
      () => TeacherExamDetailScreen(
        examId: e['id'].toString(),
        courseId: widget.courseId,
        exam: e,
      ),
    );
    if (changed == true) _load();
  }

  // -- التقييمات --
  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadEvalStudents() async {
    setState(() {
      _evalLoading = true;
      _evalError = false;
    });
    try {
      final res = await _api.fetchEvaluationStudents(
        widget.courseId,
        _dateStr(_evalDate),
      );
      _evalStudents = _list(res);
    } catch (_) {
      _evalError = true;
    } finally {
      // Always mark loaded so the lazy auto-load fires once and never loops
      // (the earlier version retried forever on failure, spamming snackbars).
      if (mounted) {
        setState(() {
          _evalLoading = false;
          _evalLoaded = true;
        });
      }
    }
  }

  Future<void> _pickEvalDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _evalDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      locale: const Locale('ar'),
    );
    if (d != null) {
      setState(() => _evalDate = d);
      _loadEvalStudents();
    }
  }

  Future<void> _evaluateStudent(Map<String, dynamic> s) async {
    final saved = await showEvaluationForm(
      context: context,
      api: _api,
      date: _dateStr(_evalDate),
      student: s,
    );
    if (saved == true) _loadEvalStudents();
  }

  List<Widget> _evaluationsTab(BuildContext context) {
    if (!_evalLoaded && !_evalLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvalStudents());
    }
    final mq = context.mq;
    final isToday = _dateStr(_evalDate) == _dateStr(DateTime.now());
    return [
      Row(
        children: [
          Expanded(child: Text('تقييم الطلاب', style: context.text.titleSmall)),
          InkWell(
            onTap: _pickEvalDate,
            borderRadius: MqRadius.brPill,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MqSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: mq.accentSoft,
                borderRadius: MqRadius.brPill,
                border: Border.all(color: mq.accentLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: mq.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isToday ? 'اليوم' : _dateStr(_evalDate),
                    style: context.text.labelSmall?.copyWith(
                      color: mq.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: MqSpacing.md),
      if (_evalLoading)
        const Padding(
          padding: EdgeInsets.all(MqSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_evalError)
        MqCard(
          padding: const EdgeInsets.all(MqSpacing.xl),
          child: Column(
            children: [
              Icon(Icons.wifi_off_rounded, size: 36, color: mq.error),
              const SizedBox(height: MqSpacing.sm),
              Text(
                'تعذّر تحميل الطلاب',
                style: context.text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MqSpacing.md),
              MqButton(
                label: 'إعادة المحاولة',
                icon: Icons.refresh_rounded,
                expand: false,
                size: MqButtonSize.small,
                onPressed: _loadEvalStudents,
              ),
            ],
          ),
        )
      else if (_evalStudents.isEmpty)
        _emptyCard(context, 'لا يوجد طلاب لتقييمهم', Icons.group_outlined)
      else
        for (final s in _evalStudents)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.sm),
            child: _EvalStudentRow(
              student: s,
              onTap: () => _evaluateStudent(s),
            ),
          ),
    ];
  }

  Widget _emptyCard(BuildContext context, String message, IconData icon) {
    final mq = context.mq;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: mq.fill2, shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: mq.ink2),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final TeacherTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final (base, soft) = switch (tone) {
      TeacherTone.success => (t.success, t.successSoft),
      TeacherTone.warning => (t.warning, t.warningSoft),
      TeacherTone.danger => (t.danger, t.dangerSoft),
      TeacherTone.info => (t.info, t.infoSoft),
      TeacherTone.neutral => (mq.ink2, mq.fill2),
    };
    return Expanded(
      child: InkWell(
        borderRadius: MqRadius.brMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
          child: Column(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: MqRadius.brMd,
                ),
                child: Icon(icon, color: base, size: MqSize.iconMd),
              ),
              const SizedBox(height: MqSpacing.sm),
              Text(
                label,
                style: context.text.labelSmall?.copyWith(color: mq.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, this.onTap});
  final Map<String, dynamic> student;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final name = (student['student_name'] ?? student['name'] ?? '—').toString();
    final phone = (student['student_phone'] ?? student['phone'] ?? '')
        .toString();

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: mq.accentSoft,
              shape: BoxShape.circle,
              border: Border.all(color: mq.accentLine),
            ),
            alignment: Alignment.center,
            child: Text(
              initialsOf(name),
              style: MqTypography.mono(
                color: mq.accent,
                size: 14,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(color: mq.ink3),
                  ),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_left_rounded, color: mq.ink3),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onTap});
  final Map<String, dynamic> session;
  final VoidCallback onTap;

  static const _days = [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  String _time(dynamic raw) {
    return formatTime12(raw);
  }

  /// The most recent occurrence (<= today) of weekday [wd], as dd/MM — this is
  /// the date the attendance screen opens for, so it lets the teacher tell the
  /// weekly sessions apart by their concrete date.
  String _recentDate(int wd) {
    if (wd < 0 || wd > 6) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      if (d.weekday % 7 == wd) {
        return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final title = (session['title'] ?? session['course_name'] ?? 'حصة')
        .toString();
    final wd = (session['weekday'] is num)
        ? (session['weekday'] as num).toInt()
        : -1;
    final dayName = (wd >= 0 && wd < 7) ? _days[wd] : '';
    final dateLabel = _recentDate(wd);
    final day = dateLabel.isEmpty ? dayName : '$dayName $dateLabel';
    final start = _time(session['start_time']);
    final end = _time(session['end_time']);

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: mq.accentSoft,
              borderRadius: MqRadius.brMd,
              border: Border.all(color: mq.accentLine),
            ),
            child: Icon(Icons.event_note_outlined, color: mq.accent, size: 20),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    day,
                    if (start.isNotEmpty) '$start - $end',
                  ].where((s) => s.isNotEmpty).join(' · '),
                  style: context.text.labelSmall?.copyWith(color: mq.ink3),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تسجيل الحضور',
                style: context.text.labelSmall?.copyWith(
                  color: mq.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.chevron_left_rounded, size: 18, color: mq.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({required this.assignment, this.onTap});
  final Map<String, dynamic> assignment;
  final VoidCallback? onTap;

  String _date(dynamic raw) {
    final s = (raw ?? '').toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final a = assignment;
    final title = (a['title'] ?? 'واجب').toString();
    final due = _date(a['due_date']);
    final score = a['max_score'];
    final active = a['is_active'] == true || a['is_active'] == 1;
    final specific = (a['visibility'] ?? '').toString() == 'specific_students';
    final sub = [
      if (due.isNotEmpty) 'التسليم: $due',
      if (score != null) 'الدرجة: $score',
      specific ? 'طلاب محدّدون' : 'كل الطلاب',
    ].join(' · ');

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: mq.accentSoft,
              borderRadius: MqRadius.brMd,
              border: Border.all(color: mq.accentLine),
            ),
            child: Icon(Icons.assignment_outlined, color: mq.accent, size: 20),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: mq.ink3),
                ),
              ],
            ),
          ),
          MqBadge(
            label: active ? 'مفعّل' : 'موقوف',
            tone: active ? MqBadgeTone.success : MqBadgeTone.neutral,
          ),
        ],
      ),
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.exam, this.onTap});
  final Map<String, dynamic> exam;
  final VoidCallback? onTap;

  String _dateTime(dynamic raw) {
    final d = DateTime.tryParse((raw ?? '').toString());
    if (d == null) return '';
    final l = d.toLocal();
    final date =
        '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    final ap = l.hour < 12 ? 'ص' : 'م';
    return '$date · $h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final e = exam;
    final type = (e['exam_type'] ?? '').toString();
    final typeLabel = type == 'monthly' ? 'شهري' : 'يومي';
    final desc = (e['description'] ?? '').toString();
    final title = desc.isNotEmpty ? desc : 'اختبار $typeLabel';
    final when = _dateTime(e['exam_date']);
    final score = e['max_score'];
    final sub = [
      if (when.isNotEmpty) when,
      if (score != null) 'الدرجة: $score',
    ].join(' · ');

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: mq.orangeSoft,
              borderRadius: MqRadius.brMd,
            ),
            child: Icon(Icons.quiz_outlined, color: mq.orange, size: 20),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: mq.ink3),
                ),
              ],
            ),
          ),
          MqBadge(label: typeLabel, tone: MqBadgeTone.orange),
        ],
      ),
    );
  }
}

class _EvalStudentRow extends StatelessWidget {
  const _EvalStudentRow({required this.student, this.onTap});
  final Map<String, dynamic> student;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final name = (student['student_name'] ?? '—').toString();
    final evaluated = (student['evaluation_id'] ?? '').toString().isNotEmpty;

    return MqCard(
      padding: const EdgeInsets.symmetric(
        horizontal: MqSpacing.md,
        vertical: MqSpacing.sm,
      ),
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: mq.accentSoft,
            child: Text(
              initialsOf(name),
              style: context.text.labelSmall?.copyWith(
                color: mq.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: MqSpacing.sm),
          MqBadge(
            label: evaluated ? 'مُقيَّم' : 'تقييم',
            tone: evaluated ? MqBadgeTone.success : MqBadgeTone.accent,
            icon: evaluated
                ? Icons.check_circle_outline
                : Icons.star_outline_rounded,
          ),
        ],
      ),
    );
  }
}
