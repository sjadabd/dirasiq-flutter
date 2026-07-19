import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/teacher_api_service.dart';
import '../../../core/utils/time_format.dart';
import '../courses/teacher_course_manage_screen.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_helpers.dart' show fmtRelative;
import '../shared/teacher_workspace.dart';
import 'widgets/teacher_platform_news_section.dart';

/// Teacher dashboard — layout matched 1:1 to `Teacher_Dashboard_Light.html`
/// (light) and `Teacher_Dashboard_Dark.html` (dark). Both modes resolve from
/// the same Teacher Design System tokens, which are lifted verbatim from those
/// files' `--wf-*` / `--t-*` custom properties, so light/dark match by
/// construction (`MqTheme.light/dark` + [TeacherTokens.light]/[dark]).
///
/// Sections, in source order:
///   1. Greeting hero        (real: name, date, study year)
///   2. KPI grid 2×2         (real: students, courses, today's sessions, pending bookings)
///   3. Revenue pair         (real: collected / outstanding from student invoices)
///   4. Today's schedule     (real: /teacher/dashboard/upcoming-today)
///   5. Quick actions        (navigation only — wired to real workspace tabs)
///   6. Performance KPIs      (real: /teacher/dashboard/performance)
///   7. Financial summary    (real: student-invoice breakdown; monthly bars omitted — no data)
///   8. Recent activity       (real: /teacher/dashboard/activity)
///
/// Real data only. No KPI value is fabricated; unsupported sections show honest
/// empty states with TODO(backend) markers rather than mock numbers.
class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  final TeacherApiService _api = TeacherApiService();

  bool _loading = false;
  bool _firstLoad = true;
  bool _online = true;
  Map<String, dynamic> _kpis = {};
  Map<String, dynamic> _perfKpis = {};
  List<Map<String, dynamic>> _todaySessions = [];
  List<Map<String, dynamic>> _activeCoursesList = [];
  List<Map<String, dynamic>> _platformNews = [];
  List<Map<String, dynamic>> _recentActivityItems = [];
  int? _pendingBookings;
  String _teacherName = '';
  String? _studyYear;

  @override
  void initState() {
    super.initState();
    _loadName();
    _fetch();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw == null) return;
    try {
      final user = jsonDecode(raw) as Map<String, dynamic>;
      if (mounted)
        setState(() => _teacherName = (user['name'] ?? '').toString());
    } catch (_) {}
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);

    Map<String, dynamic> overview = {};
    List<Map<String, dynamic>> sessions = [];
    List<Map<String, dynamic>> courses = [];
    List<Map<String, dynamic>> news = [];
    Map<String, dynamic> performance = {};
    String? studyYear;
    int? pending;
    var anyOk = false;

    Future<T?> safe<T>(Future<T> Function() run) async {
      try {
        final v = await run();
        anyOk = true;
        return v;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safe(() => _api.fetchDashboardOverview()),
      safe(() => _api.fetchTodayUpcomingSessions()),
      safe(() => _api.fetchAcademicYears()),
      safe(() => _api.fetchCourses(deleted: false, limit: 100)),
      safe(() => _api.fetchTeacherPlatformNews(limit: 8)),
      safe(() => _api.fetchDashboardPerformance()),
      safe(() => _api.fetchDashboardActivity(limit: 10)),
    ]);

    final overviewRes = results[0] as Map<String, dynamic>?;
    if (overviewRes != null) overview = _dataMap(overviewRes);

    final sessionsRes = results[1] as Map<String, dynamic>?;
    if (sessionsRes != null) sessions = _dataList(sessionsRes);

    final yearsRes = results[2] as Map<String, dynamic>?;
    if (yearsRes != null) studyYear = _activeStudyYear(yearsRes);

    final coursesRes = results[3] as Map<String, dynamic>?;
    if (coursesRes != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      courses = _dataList(coursesRes).where((c) {
        final raw = (c['end_date'] ?? c['endDate'] ?? '').toString();
        final end = DateTime.tryParse(raw);
        if (end == null) return true;
        final endDay = DateTime(end.year, end.month, end.day);
        return !endDay.isBefore(today);
      }).toList();
    }

    final newsRaw = results[4];
    if (newsRaw is List) {
      news = newsRaw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }

    final perfRes = results[5] as Map<String, dynamic>?;
    if (perfRes != null) performance = _dataMap(perfRes);

    List<Map<String, dynamic>> activity = [];
    final activityRes = results[6] as Map<String, dynamic>?;
    if (activityRes != null) activity = _dataList(activityRes);

    try {
      if (studyYear != null && studyYear.isNotEmpty) {
        final stats = await _api.fetchBookingStats(studyYear);
        final v = _dataMap(stats)['pendingBookings'];
        pending = (v is num) ? v.toInt() : int.tryParse('${v ?? ''}');
        anyOk = true;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _kpis = overview;
      _todaySessions = sessions;
      _activeCoursesList = courses;
      _platformNews = news;
      _perfKpis = performance;
      _recentActivityItems = activity;
      _pendingBookings = pending;
      _studyYear = studyYear;
      _online = anyOk;
      _firstLoad = false;
      _loading = false;
    });

    if (!anyOk) {
      Get.snackbar(
        'خطأ',
        'تعذّر جلب بيانات اللوحة',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ---- response helpers -----------------------------------------------------

  Map<String, dynamic> _dataMap(Map<String, dynamic> envelope) {
    final d = envelope['data'];
    return (d is Map) ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _dataList(Map<String, dynamic> envelope) {
    final d = envelope['data'];
    if (d is List) {
      return d
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    if (d is Map) {
      final nested = d['items'] ?? d['courses'] ?? d['sessions'] ?? d['data'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    }
    return const [];
  }

  String _activeStudyYear(Map<String, dynamic> envelope) {
    final d = _dataMap(envelope);
    final active = d['active'];
    if (active is Map && active['year'] != null)
      return active['year'].toString();
    final now = DateTime.now();
    final y = now.year;
    return now.month >= 9 ? '$y-${y + 1}' : '${y - 1}-$y';
  }

  // ---- formatting -----------------------------------------------------------

  num _num(dynamic n) => (n is num) ? n : (num.tryParse('${n ?? ''}') ?? 0);

  String _int(dynamic n) => _num(n).toInt().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );

  int _pct(num part, num whole) =>
      whole <= 0 ? 0 : (part / whole * 100).round().clamp(0, 100);

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'صباح الخير 👋' : 'مساء الخير 👋';
  }

  String _fullDate() {
    final d = DateTime.now();
    const days = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${days[d.weekday - 1]}، ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// The academic term, derived from the calendar (the backend has no term/
  /// semester field — only the `YYYY-YYYY` study year). Iraqi school calendar:
  /// first term ≈ Sep–Jan, second term ≈ Feb–Jun, summer break otherwise.
  String _term() {
    final m = DateTime.now().month;
    if (m >= 9 || m == 1) return 'الفصل الأول';
    if (m >= 2 && m <= 6) return 'الفصل الثاني';
    return 'العطلة الصيفية';
  }

  String _remainingLabel(int n) {
    if (n <= 0) return 'لا حصص متبقّية';
    if (n == 1) return 'حصة متبقّية';
    if (n == 2) return 'حصّتان متبقّيتان';
    if (n <= 10) return '$n حصص متبقّية';
    return '$n حصة متبقّية';
  }

  String _time(dynamic raw) {
    return formatTime12(raw).split(' ').first;
  }

  String _period(dynamic raw) {
    final parts = formatTime12(raw).split(' ');
    return parts.length > 1 ? parts.last : '';
  }

  (String, TeacherTone) _sessionState(dynamic raw) {
    switch ((raw ?? '').toString()) {
      case 'confirmed':
        return ('مؤكدة', TeacherTone.success);
      case 'proposed':
        return ('مقترحة', TeacherTone.info);
      case 'negotiating':
        return ('قيد التنسيق', TeacherTone.warning);
      case 'conflict':
        return ('تعارض', TeacherTone.danger);
      default:
        return ('مسودة', TeacherTone.neutral);
    }
  }

  void _go(int index) => TeacherWorkspace.switchTo(context, index);

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
              appBar: const TeacherAppBar(title: 'لوحة التحكم'),
              drawer: const TeacherDrawer(),
              body: RefreshIndicator(
                onRefresh: _fetch,
                color: mq.accent,
                child: _firstLoad && _loading
                    ? const _DashboardSkeleton()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          MqSpacing.lg,
                          MqSpacing.lg,
                          MqSpacing.lg,
                          MqSpacing.xl,
                        ),
                        children: [
                          if (_platformNews.isNotEmpty) ...[
                            TeacherPlatformNewsSection(
                              items: _platformNews,
                              onOpen: (item) =>
                                  showTeacherPlatformNewsDetail(context, item),
                            ),
                            const SizedBox(height: MqSpacing.md),
                          ],
                          _hero(context),
                          const SizedBox(height: MqSpacing.md),
                          _revenuePair(context),
                          const SizedBox(height: MqSpacing.md),
                          _todaySchedule(context),
                          const SizedBox(height: MqSpacing.md),
                          _activeCourses(context),
                          const SizedBox(height: MqSpacing.md),
                          _quickActions(context),
                          const SizedBox(height: MqSpacing.md),
                          _performance(context),
                          const SizedBox(height: MqSpacing.md),
                          _financialSummary(context),
                          const SizedBox(height: MqSpacing.md),
                          _recentActivity(context),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---- 1. hero (greeting + embedded KPI strip) ------------------------------

  Widget _hero(BuildContext context) {
    final t = context.teacher;
    final name = _teacherName.isEmpty ? 'أستاذ' : _teacherName;
    final remaining = _todaySessions.length;
    final pending = _pendingBookings;

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
          // Greeting + name + identity avatar (avatar opens profile).
          Row(
            children: [
              GestureDetector(
                onTap: () => _go(TeacherWorkspaceState.profileIdx),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: context.mq.orange,
                  child: Text(
                    _teacherName.isNotEmpty
                        ? _teacherName.characters.first
                        : '؟',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: context.text.labelMedium?.copyWith(
                        color: t.heroInk2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'أ. $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleLarge?.copyWith(
                        color: t.heroInk,
                      ),
                    ),
                  ],
                ),
              ),
              _onlinePill(context),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          // Date • term.
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 13, color: t.heroInk2),
              const SizedBox(width: MqSpacing.xs),
              Expanded(
                child: Text(
                  '${_fullDate()} • ${_term()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: t.heroInk2),
                ),
              ),
            ],
          ),
          const SizedBox(height: MqSpacing.lg),
          // Embedded KPI strip — real data.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroStat(
                  label: 'إجمالي الطلاب',
                  value: _int(_kpis['totalStudents']),
                  sub: '${_int(_kpis['activeStudents'])} نشط',
                  subTone: _HeroSubTone.success,
                ),
                const SizedBox(width: MqSpacing.sm),
                _HeroStat(
                  label: 'الدورات الفعّالة',
                  value: _int(_kpis['activeCourses']),
                  sub: 'من ${_int(_kpis['totalCourses'])} دورة',
                ),
                const SizedBox(width: MqSpacing.sm),
                _HeroStat(
                  label: 'حصص اليوم',
                  value: _int(_kpis['sessionsToday']),
                  sub: _remainingLabel(remaining),
                ),
                const SizedBox(width: MqSpacing.sm),
                _HeroStat(
                  label: 'حجوزات معلّقة',
                  value: pending == null ? '—' : _int(pending),
                  sub: 'بحاجة لمراجعة',
                  highlight: (pending ?? 0) > 0,
                  onTap: (pending ?? 0) > 0
                      ? () => _go(TeacherWorkspaceState.bookingsIdx)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _onlinePill(BuildContext context) {
    final t = context.teacher;
    final color = _online ? t.success : t.heroInk2;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MqSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: t.heroTile,
        borderRadius: MqRadius.brPill,
        border: Border.all(color: t.heroLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: MqSpacing.xs),
          Text(
            _online ? 'متصل' : 'غير متصل',
            style: context.text.labelSmall?.copyWith(color: t.heroInk),
          ),
        ],
      ),
    );
  }

  // ---- 3. revenue pair ------------------------------------------------------

  Widget _revenuePair(BuildContext context) {
    final s = (_kpis['studentInvoices'] is Map)
        ? Map<String, dynamic>.from(_kpis['studentInvoices'])
        : const {};
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _RevenueCard(
              label: 'الإيراد المُحصّل',
              value: _int(s['amountPaid']),
              icon: Icons.trending_up_rounded,
              tone: TeacherTone.success,
            ),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: _RevenueCard(
              label: 'مدفوعات مستحقّة',
              value: _int(s['amountRemaining']),
              icon: Icons.account_balance_wallet_outlined,
              tone: TeacherTone.danger,
              onTap: () => _go(TeacherWorkspaceState.invoicesIdx),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 4. today's schedule --------------------------------------------------

  Widget _todaySchedule(BuildContext context) {
    final n = _todaySessions.length;
    final remaining =
        _todaySessions.where((s) => s['isPast'] != true).length;
    return TeacherDashboardCard(
      title: 'جدول اليوم',
      subtitle: n > 0
          ? (remaining > 0 ? '$remaining متبقّية من $n' : '$n حصص اليوم')
          : null,
      icon: Icons.today_outlined,
      tone: TeacherTone.info,
      trailing: _SeeAll(
        label: 'الجدول الكامل',
        onTap: () => _go(TeacherWorkspaceState.sessionsIdx),
      ),
      child: _todaySessions.isEmpty
          ? const TeacherEmptyState(
              message: 'لا توجد حصص لهذا اليوم',
              icon: Icons.event_busy_outlined,
              dense: true,
            )
          : Column(
              children: [
                for (var i = 0; i < _todaySessions.length; i++)
                  _scheduleRow(
                    context,
                    _todaySessions[i],
                    last: i == _todaySessions.length - 1,
                  ),
              ],
            ),
    );
  }

  Widget _scheduleRow(
    BuildContext context,
    Map<String, dynamic> s, {
    required bool last,
  }) {
    final mq = context.mq;
    final isPast = s['isPast'] == true;
    final (label, tone) = isPast
        ? ('انتهت', TeacherTone.neutral)
        : _sessionState(s['state']);
    final title = (s['courseName'] ?? s['title'] ?? 'حصة').toString();

    final row = InkWell(
      borderRadius: MqRadius.brMd,
      onTap: () => _go(TeacherWorkspaceState.sessionsIdx),
      child: Opacity(
        opacity: isPast ? 0.65 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
                decoration: BoxDecoration(
                  color: mq.fill,
                  borderRadius: MqRadius.brSm,
                  border: Border.all(color: mq.line),
                ),
                child: Column(
                  children: [
                    Text(
                      _time(s['startTime']),
                      style: MqTypography.mono(
                        color: mq.ink,
                        size: 14,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _period(s['startTime']),
                      style: context.text.labelSmall?.copyWith(color: mq.ink3),
                    ),
                  ],
                ),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    TeacherStatusPill(label: label, tone: tone, dense: true),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: mq.ink3),
            ],
          ),
        ),
      ),
    );

    if (last) return row;
    return Column(
      children: [
        row,
        Divider(height: 1, color: mq.line),
      ],
    );
  }

  // ---- active courses (tap → course management) -----------------------------

  Widget _activeCourses(BuildContext context) {
    final n = _activeCoursesList.length;
    return TeacherDashboardCard(
      title: 'الدورات النشطة',
      subtitle: n > 0 ? '$n دورة' : null,
      icon: Icons.menu_book_outlined,
      tone: TeacherTone.success,
      child: _activeCoursesList.isEmpty
          ? const TeacherEmptyState(
              message: 'لا توجد دورات نشطة',
              icon: Icons.menu_book_outlined,
              dense: true,
            )
          : Column(
              children: [
                for (var i = 0; i < _activeCoursesList.length; i++)
                  _courseRow(
                    context,
                    _activeCoursesList[i],
                    last: i == _activeCoursesList.length - 1,
                  ),
              ],
            ),
    );
  }

  Widget _courseRow(
    BuildContext context,
    Map<String, dynamic> c, {
    required bool last,
  }) {
    final mq = context.mq;
    final name = (c['course_name'] ?? c['courseName'] ?? 'دورة').toString();
    final grade = (c['grade_name'] ?? c['gradeName'] ?? '').toString();
    final year = (c['study_year'] ?? c['studyYear'] ?? '').toString();
    final meta = [grade, year].where((s) => s.isNotEmpty).join(' · ');

    final row = InkWell(
      borderRadius: MqRadius.brMd,
      onTap: () => _openManage(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: mq.accentSoft,
                borderRadius: MqRadius.brMd,
                border: Border.all(color: mq.accentLine),
              ),
              child: Icon(Icons.menu_book_outlined, color: mq.accent, size: 20),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: mq.ink3),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: mq.ink3),
          ],
        ),
      ),
    );

    if (last) return row;
    return Column(
      children: [
        row,
        Divider(height: 1, color: mq.line),
      ],
    );
  }

  Future<void> _openManage(Map<String, dynamic> c) async {
    await Get.to(
      () => TeacherCourseManageScreen(courseId: c['id'].toString(), course: c),
    );
    _fetch();
  }

  // ---- 5. quick actions -----------------------------------------------------

  Widget _quickActions(BuildContext context) {
    // Wired to real workspace destinations only. The HTML's "إنشاء واجب / إنشاء
    // اختبار" tiles have no teacher screens in this app, so they're replaced by
    // supported operational shortcuts (invoices / bookings).
    return TeacherDashboardCard(
      title: 'إجراءات سريعة',
      icon: Icons.bolt_outlined,
      tone: TeacherTone.warning,
      child: Row(
        children: [
          _QuickAction(
            icon: Icons.fact_check_outlined,
            label: 'تسجيل الحضور',
            tone: TeacherTone.info,
            onTap: () => _go(TeacherWorkspaceState.sessionsIdx),
          ),
          _QuickAction(
            icon: Icons.campaign_outlined,
            label: 'إعلان جديد',
            tone: TeacherTone.warning,
            onTap: () => _go(TeacherWorkspaceState.notificationsIdx),
          ),
          _QuickAction(
            icon: Icons.receipt_long_outlined,
            label: 'الفواتير',
            tone: TeacherTone.success,
            onTap: () => _go(TeacherWorkspaceState.invoicesIdx),
          ),
          _QuickAction(
            icon: Icons.assignment_turned_in_outlined,
            label: 'الحجوزات',
            tone: TeacherTone.danger,
            onTap: () => _go(TeacherWorkspaceState.bookingsIdx),
          ),
        ],
      ),
    );
  }

  // ---- 6. performance -------------------------------------------------------

  Widget _performance(BuildContext context) {
    final mq = context.mq;
    final att = _perfKpis['attendanceRate'];
    final hw = _perfKpis['homeworkRate'];
    final col = _perfKpis['collectionRate'];
    final hasAny = att != null || hw != null || col != null;

    return TeacherDashboardCard(
      title: 'مؤشّرات الأداء',
      subtitle: 'هذا الشهر',
      icon: Icons.insights_outlined,
      tone: TeacherTone.neutral,
      child: !hasAny
          ? const TeacherEmptyState(
              message: 'لا توجد بيانات كافية لحساب المؤشرات بعد',
              icon: Icons.query_stats_outlined,
              dense: true,
            )
          : Column(
              children: [
                _perfRow(
                  context,
                  label: 'الحضور',
                  value: att,
                  icon: Icons.event_available_outlined,
                  tone: TeacherTone.info,
                ),
                Divider(height: 1, color: mq.line),
                _perfRow(
                  context,
                  label: 'تسليم الواجبات',
                  value: hw,
                  icon: Icons.assignment_turned_in_outlined,
                  tone: TeacherTone.success,
                ),
                Divider(height: 1, color: mq.line),
                _perfRow(
                  context,
                  label: 'تحصيل الفواتير',
                  value: col,
                  icon: Icons.payments_outlined,
                  tone: TeacherTone.warning,
                ),
              ],
            ),
    );
  }

  Widget _perfRow(
    BuildContext context, {
    required String label,
    required dynamic value,
    required IconData icon,
    required TeacherTone tone,
  }) {
    final mq = context.mq;
    final t = context.teacher;
    final pct = value is num ? value.toInt() : null;
    final color = switch (tone) {
      TeacherTone.success => t.success,
      TeacherTone.warning => t.warning,
      TeacherTone.danger => t.danger,
      TeacherTone.info => t.info,
      _ => mq.accent,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: MqRadius.brSm,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Text(
              label,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            pct == null ? '—' : '$pct٪',
            style: MqTypography.mono(
              color: pct == null ? mq.ink3 : mq.ink,
              size: 16,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---- 7. financial summary -------------------------------------------------

  Widget _financialSummary(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final s = (_kpis['studentInvoices'] is Map)
        ? Map<String, dynamic>.from(_kpis['studentInvoices'])
        : const {};
    final due = _num(s['totalDue']);
    final paid = _num(s['amountPaid']);
    final remaining = _num(s['amountRemaining']);
    final paidPct = _pct(paid, due);
    final remPct = _pct(remaining, due);

    // NOTE: the HTML's monthly revenue bar chart (يناير…نوفمبر) is intentionally
    // omitted — there is no per-month revenue endpoint, so drawing bars would
    // fabricate data. The real collected/remaining breakdown is shown instead.
    return TeacherDashboardCard(
      title: 'الملخّص المالي',
      subtitle: 'فواتير الطلاب${_studyYear != null ? ' · $_studyYear' : ''}',
      icon: Icons.bar_chart_outlined,
      tone: TeacherTone.info,
      trailing: _SeeAll(
        label: 'الفواتير',
        onTap: () => _go(TeacherWorkspaceState.invoicesIdx),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإيراد المتوقّع',
            style: context.text.labelMedium?.copyWith(color: mq.ink2),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _int(due),
                style: MqTypography.mono(
                  color: mq.ink,
                  size: 24,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: MqSpacing.xs),
              Text(
                'د.ع',
                style: context.text.labelMedium?.copyWith(color: mq.ink3),
              ),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          TeacherMiniChart(
            segments: [
              TeacherChartSegment(paid.toDouble(), TeacherTone.success),
              TeacherChartSegment(remaining.toDouble(), TeacherTone.danger),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          TeacherDataRow(
            label: 'المُحصّل',
            value: _int(paid),
            icon: Icons.check_circle_outline,
            iconTone: TeacherTone.success,
            valueColor: t.success,
            mono: true,
            trailing: TeacherStatusPill(
              label: '$paidPct٪',
              tone: TeacherTone.success,
              dense: true,
            ),
          ),
          TeacherDataRow(
            label: 'المتبقّي (مستحق)',
            value: _int(remaining),
            icon: Icons.schedule_outlined,
            iconTone: TeacherTone.danger,
            valueColor: t.danger,
            mono: true,
            trailing: TeacherStatusPill(
              label: '$remPct٪',
              tone: TeacherTone.danger,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  // ---- 8. recent activity ---------------------------------------------------

  Widget _recentActivity(BuildContext context) {
    final items = _recentActivityItems;
    return TeacherDashboardCard(
      title: 'آخر النشاطات',
      icon: Icons.history_outlined,
      tone: TeacherTone.neutral,
      trailing: items.isEmpty
          ? null
          : _SeeAll(
              label: 'الحجوزات',
              onTap: () => _go(TeacherWorkspaceState.bookingsIdx),
            ),
      child: items.isEmpty
          ? const TeacherEmptyState(
              message: 'سيظهر هنا أحدث النشاطات عند توفّرها',
              icon: Icons.notifications_none_outlined,
              dense: true,
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _activityRow(
                    context,
                    items[i],
                    last: i == items.length - 1,
                  ),
              ],
            ),
    );
  }

  Widget _activityRow(
    BuildContext context,
    Map<String, dynamic> a, {
    required bool last,
  }) {
    final mq = context.mq;
    final kind = (a['kind'] ?? '').toString();
    final title = (a['title'] ?? 'نشاط').toString();
    final subtitle = (a['subtitle'] ?? '').toString();
    final when = fmtRelative(
      (a['occurredAt'] ?? a['occurred_at'])?.toString(),
    );
    final (icon, tone) = switch (kind) {
      'deposit' || 'invoice' => (
          Icons.payments_outlined,
          TeacherTone.success,
        ),
      'booking' => (Icons.how_to_reg_outlined, TeacherTone.info),
      _ => (Icons.notifications_none_outlined, TeacherTone.neutral),
    };
    final t = context.teacher;
    final color = switch (tone) {
      TeacherTone.success => t.success,
      TeacherTone.warning => t.warning,
      TeacherTone.danger => t.danger,
      TeacherTone.info => t.info,
      TeacherTone.neutral => mq.ink2,
    };
    final soft = switch (tone) {
      TeacherTone.success => t.successSoft,
      TeacherTone.warning => t.warningSoft,
      TeacherTone.danger => t.dangerSoft,
      TeacherTone.info => t.infoSoft,
      TeacherTone.neutral => mq.fill2,
    };

    final row = InkWell(
      borderRadius: MqRadius.brMd,
      onTap: () {
        if (kind == 'invoice') {
          _go(TeacherWorkspaceState.invoicesIdx);
        } else {
          _go(TeacherWorkspaceState.bookingsIdx);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: soft,
                borderRadius: MqRadius.brSm,
              ),
              child: Icon(icon, size: 18, color: color),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: mq.ink3),
                    ),
                  ],
                ],
              ),
            ),
            if (when.isNotEmpty)
              Text(
                when,
                style: context.text.labelSmall?.copyWith(color: mq.ink3),
              ),
          ],
        ),
      ),
    );

    if (last) return row;
    return Column(
      children: [
        row,
        Divider(height: 1, color: mq.line),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Local widgets
// ---------------------------------------------------------------------------

enum _HeroSubTone { muted, success }

/// One translucent KPI tile embedded in the dashboard hero strip. Sits on the
/// gradient, so it uses the hero ink/tile tokens. Value renders in mono.
class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.sub,
    this.subTone = _HeroSubTone.muted,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final String value;
  final String sub;
  final _HeroSubTone subTone;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.teacher;
    final valueColor = highlight ? t.warning : t.heroInk;
    final subColor = highlight
        ? t.warning
        : (subTone == _HeroSubTone.success ? t.success : t.heroInk2);

    final tile = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MqSpacing.sm,
        vertical: MqSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: t.heroTile,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: highlight ? t.warningLine : t.heroLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(color: t.heroInk2),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: MqTypography.mono(
                color: valueColor,
                size: 20,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subTone == _HeroSubTone.success && !highlight) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: subColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: subColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Expanded(
      child: onTap == null
          ? tile
          : InkWell(borderRadius: MqRadius.brMd, onTap: onTap, child: tile),
    );
  }
}

/// A compact revenue figure card (icon badge + big mono value + unit + label).
class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final TeacherTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final base = switch (tone) {
      TeacherTone.success => t.success,
      TeacherTone.danger => t.danger,
      TeacherTone.warning => t.warning,
      TeacherTone.info => t.info,
      TeacherTone.neutral => mq.ink2,
    };
    final soft = switch (tone) {
      TeacherTone.success => t.successSoft,
      TeacherTone.danger => t.dangerSoft,
      TeacherTone.warning => t.warningSoft,
      TeacherTone.info => t.infoSoft,
      TeacherTone.neutral => mq.fill2,
    };

    return MqCard(
      onTap: onTap,
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(MqSpacing.sm),
            decoration: BoxDecoration(color: soft, borderRadius: MqRadius.brSm),
            child: Icon(icon, size: MqSize.iconSm, color: base),
          ),
          const SizedBox(height: MqSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: MqTypography.mono(
                      color: mq.ink,
                      size: 20,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: MqSpacing.xs),
              Text(
                'د.ع',
                style: context.text.labelSmall?.copyWith(color: mq.ink3),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(color: mq.ink2),
          ),
        ],
      ),
    );
  }
}

/// A single quick-action tile (tinted icon + label), expands to fill its row.
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
      TeacherTone.danger => (t.danger, t.dangerSoft),
      TeacherTone.warning => (t.warning, t.warningSoft),
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
                textAlign: TextAlign.center,
                maxLines: 2,
                style: context.text.labelSmall?.copyWith(color: mq.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A "see all ›" trailing action for a [TeacherDashboardCard] header.
class _SeeAll extends StatelessWidget {
  const _SeeAll({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return InkWell(
      borderRadius: MqRadius.brPill,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MqSpacing.sm,
          vertical: MqSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: mq.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.chevron_left_rounded, size: 16, color: mq.accent),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    Widget block(double h, {BorderRadius? r}) => Container(
      height: h,
      decoration: BoxDecoration(
        color: mq.fill2,
        borderRadius: r ?? MqRadius.brMd,
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        block(108, r: MqRadius.brXl),
        const SizedBox(height: MqSpacing.lg),
        Row(
          children: [
            Expanded(child: block(92)),
            const SizedBox(width: MqSpacing.md),
            Expanded(child: block(92)),
          ],
        ),
        const SizedBox(height: MqSpacing.md),
        Row(
          children: [
            Expanded(child: block(92)),
            const SizedBox(width: MqSpacing.md),
            Expanded(child: block(92)),
          ],
        ),
        const SizedBox(height: MqSpacing.lg),
        block(150, r: MqRadius.brLg),
        const SizedBox(height: MqSpacing.md),
        block(150, r: MqRadius.brLg),
      ],
    );
  }
}
