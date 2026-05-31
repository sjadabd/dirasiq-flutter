import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/global_app_bar.dart';
import '../../../shared/widgets/status_views.dart';
import '../../course_hub/screens/course_hub_screen.dart';
import '../../course_hub/screens/teacher_courses_picker_screen.dart';
import '../../teachers/screens/suggested_teachers_screen.dart';
import '../../teachers/screens/teacher_details_screen.dart';
import '../../teachers/screens/teacher_student_workspace_screen.dart';
import '../../courses/screens/suggested_courses_screen.dart';
import '../../courses/screens/course_details_screen.dart';
import '../widgets/news_carousel.dart';
import '../widgets/student_calendar.dart';

/// Student home (v2) — comprehensive student dashboard.
///
/// Section order (top-to-bottom, per the latest UX feedback):
///   1. GlobalAppBar (search + theme + notifications + profile)
///   2. News / ads carousel — first thing the student sees
///   3. Next session + Next exam — two-card row with live countdown
///   4. أساتذتي — the teacher-relationship cards (tap → workspace)
///   5. Progress + attendance card — the two mini-meters
///   6. Suggested teachers row
///   7. Suggested courses row
///   8. Weekly calendar with lessons
///
/// All data fetched in parallel from existing endpoints — no backend changes.
/// Pull-to-refresh refetches everything.
class StudentMyTeachersHome extends StatefulWidget {
  const StudentMyTeachersHome({super.key});
  @override
  State<StudentMyTeachersHome> createState() => _StudentMyTeachersHomeState();
}

class _StudentMyTeachersHomeState extends State<StudentMyTeachersHome> {
  final _api = ApiService();
  bool _loading = false;
  String _name = '';
  String _contentUrl = '';

  // Sources
  List<_MyTeacher> _myTeachers = const [];
  Map<String, dynamic> _overview = const {};
  List<dynamic> _suggestedTeachers = const [];
  List<dynamic> _suggestedCourses = const [];

  // Countdown ticker for the next-session / next-exam cards
  Timer? _ticker;

  // Bumped on every pull-to-refresh so child widgets that fetch their own
  // data (NewsCarousel, StudentCalendar) reload too. Without this their
  // initState fetch is the only one — pull-to-refresh would leave them stale.
  int _childRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _loadName();
    _fetchAll();
    // 1-second ticker just to refresh the countdown label.
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    _contentUrl = prefs.getString('content_url') ?? 'https://api.mulhimiq.com';
    if (raw == null) return;
    try {
      final user = jsonDecode(raw) as Map<String, dynamic>;
      setState(() => _name = (user['name'] ?? '').toString());
    } catch (_) {}
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      // Force child widgets (NewsCarousel, StudentCalendar) to refetch by
      // bumping the token they watch in didUpdateWidget.
      _childRefreshToken++;
    });
    try {
      final results = await Future.wait<dynamic>([
        _api.fetchStudentEnrollments(),         // → my teachers
        _api.fetchStudentDashboardOverview(),   // → next session/exam + progress
        _api.fetchSuggestedTeachers(),          // → discover row
        _api.fetchSuggestedCourses(maxDistance: 50), // → discover row
      ]);

      final enrollData = (results[0] as Map?)?['data'];
      _myTeachers = _groupByTeacher(
        enrollData is List ? List<Map<String, dynamic>>.from(enrollData) : <Map<String, dynamic>>[],
      );

      final overviewData = (results[1] as Map?)?['data'];
      _overview = overviewData is Map ? Map<String, dynamic>.from(overviewData) : const {};

      final teachersData = (results[2] as Map?)?['data'];
      _suggestedTeachers = teachersData is List ? List.from(teachersData) : const [];

      _suggestedCourses = (results[3] is List) ? results[3] as List : const [];
    } catch (_) {
      // each section degrades to an empty state
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_MyTeacher> _groupByTeacher(List<Map<String, dynamic>> enrollments) {
    final groups = <String, _MyTeacher>{};
    for (final e in enrollments) {
      final t = (e['teacher'] is Map) ? Map<String, dynamic>.from(e['teacher']) : <String, dynamic>{};
      final id = t['id']?.toString();
      if (id == null) continue;
      final c = (e['course'] is Map) ? Map<String, dynamic>.from(e['course']) : <String, dynamic>{};
      groups.putIfAbsent(id, () => _MyTeacher(
        id: id,
        name: (t['name'] ?? '').toString(),
        photo: (t['profileImagePath'] ?? '').toString(),
        courses: [],
      ));
      groups[id]!.courses.add(_TeacherCourse(
        id: (c['id'] ?? '').toString(),
        name: (c['name'] ?? '').toString(),
        startDate: c['startDate']?.toString(),
        endDate: c['endDate']?.toString(),
        image: (c['images'] is List && (c['images'] as List).isNotEmpty) ? (c['images'] as List).first.toString() : null,
        bookingId: (e['bookingId'] ?? '').toString(),
        status: (e['status'] ?? '').toString(),
      ));
    }
    return groups.values.toList();
  }

  String _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('data:')) return path;
    final base = _contentUrl.replaceAll(RegExp(r'/$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return '$base$p';
  }

  String _countdown(dynamic isoDate) {
    if (isoDate == null) return '—';
    final target = DateTime.tryParse(isoDate.toString());
    if (target == null) return '—';
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return 'انتهت';
    if (diff.inDays >= 1) return 'بعد ${diff.inDays} يوم';
    if (diff.inHours >= 1) return 'بعد ${diff.inHours} ساعة';
    if (diff.inMinutes >= 1) return 'بعد ${diff.inMinutes} دقيقة';
    return 'الآن';
  }

  void _openTeacherWorkspace(_MyTeacher t) {
    if (!AppConfig.useNewCourseHub) {
      Get.to(() => TeacherStudentWorkspaceScreen(
        teacherId: t.id,
        teacherName: t.name,
        courses: t.courses.map((c) => {
          'id': c.id, 'name': c.name, 'bookingId': c.bookingId, 'status': c.status,
        }).toList(),
      ));
      return;
    }

    // Phase 6 — feature flag is on. Single-course teachers go straight to
    // the Course Hub; multi-course teachers go through the picker.
    if (t.courses.length == 1) {
      final c = t.courses.first;
      Get.to(() => CourseHubScreen(
        courseId: c.id,
        courseName: c.name,
        teacherId: t.id,
      ));
    } else {
      Get.to(() => TeacherCoursesPickerScreen(
        teacherId: t.id,
        teacherName: t.name,
        courses: t.courses.map((c) => {
          'id': c.id, 'name': c.name, 'bookingId': c.bookingId, 'status': c.status,
        }).toList(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nextSession = _overview['nextSession'] is Map ? Map<String, dynamic>.from(_overview['nextSession']) : null;
    final nextExam    = _overview['nextMonthlyExam'] is Map ? Map<String, dynamic>.from(_overview['nextMonthlyExam']) : null;
    final progress    = ((_overview['progressPercent']  ?? 0) as num).toInt();
    final attendance  = ((_overview['attendancePercent'] ?? 0) as num).toInt();

    return Scaffold(
      appBar: GlobalAppBar(title: 'الرئيسية'),
      body: RefreshIndicator(
        onRefresh: _fetchAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ─── News / Ads carousel (top) ──────────────────────────────
            _SectionHeader(
              icon: Icons.campaign_outlined,
              accent: const Color(0xFFFF8A00),
              title: 'إعلانات وأخبار',
              subtitle: 'آخر الإعلانات من المنصّة',
            ),
            const SizedBox(height: 10),
            NewsCarousel(refreshToken: _childRefreshToken),
            const SizedBox(height: 20),

            // ─── Next session + Next exam ───────────────────────────────
            Row(children: [
              Expanded(child: _NextItemCard(
                title: 'أقرب محاضرة',
                emptyText: 'لا توجد محاضرة قريبة',
                icon: Icons.event_outlined,
                color: const Color(0xFF3FA9F5),
                primary: nextSession?['courseName']?.toString(),
                secondary: nextSession?['teacher']?['name']?.toString(),
                countdown: _countdown(nextSession?['nextOccurrence']),
              )),
              const SizedBox(width: 10),
              Expanded(child: _NextItemCard(
                title: 'أقرب امتحان',
                emptyText: 'لا يوجد امتحان قريب',
                icon: Icons.quiz_outlined,
                color: const Color(0xFF9333EA),
                primary: nextExam?['title']?.toString(),
                secondary: nextExam?['courseName']?.toString(),
                countdown: _countdown(nextExam?['examDate']),
              )),
            ]),
            const SizedBox(height: 20),

            // ─── أساتذتي ────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.cast_for_education_outlined,
              accent: cs.primary,
              title: 'أساتذتي',
              subtitle: 'تابع كل ما يخص علاقتك مع كل أستاذ',
              trailing: _myTeachers.isNotEmpty ? Text('${_myTeachers.length}', style: TextStyle(color: cs.onSurfaceVariant)) : null,
            ),
            const SizedBox(height: 10),

            if (_loading && _myTeachers.isEmpty)
              const StatusView.loading(message: 'جارٍ تحضير أساتذتك…')
            else if (_myTeachers.isEmpty)
              const _EmptyMyTeachers()
            else
              SizedBox(
                height: 218,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _myTeachers.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) => _ProfessionalTeacherCard(
                    teacher: _myTeachers[i],
                    onTap: () => _openTeacherWorkspace(_myTeachers[i]),
                    resolveImage: _resolveImageUrl,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ─── Progress + attendance card (below أساتذتي) ─────────────
            _ProgressAttendanceCard(name: _name, progress: progress, attendance: attendance),

            const SizedBox(height: 16),

            // ─── Video courses CTA (Phase 10.1) ─────────────────────────
            _VideoCoursesPromo(onTap: () => Get.toNamed('/student/video-courses')),

            const SizedBox(height: 24),

            // ─── Suggested teachers ─────────────────────────────────────
            _SectionHeader(
              icon: Icons.person_search_outlined,
              accent: const Color(0xFF3FA9F5),
              title: 'معلمون مقترحون',
              subtitle: 'تعرّف على معلمين جدد',
              actionLabel: 'الكل',
              onAction: () => Get.to(() => const SuggestedTeachersScreen()),
            ),
            const SizedBox(height: 10),
            if (_suggestedTeachers.isEmpty)
              _MutedEmpty(text: 'لا يوجد معلمون مقترحون حالياً')
            else
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestedTeachers.length.clamp(0, 10),
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) {
                    final raw = _suggestedTeachers[i];
                    if (raw is! Map) return const SizedBox.shrink();
                    final t = Map<String, dynamic>.from(raw);
                    return _SuggestedTeacherTile(
                      name: (t['name'] ?? '—').toString(),
                      photo: _resolveImageUrl(t['profileImagePath']?.toString()),
                      onTap: () => Get.to(() => TeacherDetailsScreen(teacherId: (t['id'] ?? '').toString())),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // ─── Suggested courses ──────────────────────────────────────
            _SectionHeader(
              icon: Icons.school_outlined,
              accent: const Color(0xFF9333EA),
              title: 'كورسات مقترحة',
              subtitle: 'كورسات قد تهمّك',
              actionLabel: 'الكل',
              onAction: () => Get.to(() => const SuggestedCoursesScreen()),
            ),
            const SizedBox(height: 10),
            if (_suggestedCourses.isEmpty)
              _MutedEmpty(text: 'لا توجد كورسات مقترحة حالياً')
            else
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestedCourses.length.clamp(0, 10),
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) {
                    final raw = _suggestedCourses[i];
                    if (raw is! Map) return const SizedBox.shrink();
                    final c = Map<String, dynamic>.from(raw);
                    final img = (c['course_images'] is List && (c['course_images'] as List).isNotEmpty)
                        ? _resolveImageUrl((c['course_images'] as List).first.toString())
                        : '';
                    return _SuggestedCourseTile(
                      name: (c['course_name'] ?? c['name'] ?? '—').toString(),
                      teacherName: (c['teacher_name'] ?? '').toString(),
                      image: img,
                      onTap: () => Get.to(() => CourseDetailsScreen(courseId: (c['id'] ?? '').toString())),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // ─── Weekly calendar (moved to bottom) ──────────────────────
            _SectionHeader(
              icon: Icons.calendar_month_outlined,
              accent: const Color(0xFF10B981),
              title: 'جدولي الأسبوعي',
              subtitle: 'دروسك في كل يوم',
            ),
            const SizedBox(height: 10),
            StudentCalendar(refreshToken: _childRefreshToken),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _MyTeacher {
  _MyTeacher({required this.id, required this.name, required this.photo, required this.courses});
  final String id, name, photo;
  final List<_TeacherCourse> courses;
}

class _TeacherCourse {
  _TeacherCourse({required this.id, required this.name, required this.bookingId, required this.status, this.startDate, this.endDate, this.image});
  final String id, name, bookingId, status;
  final String? startDate, endDate, image;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Light-themed progress + attendance card.
///
/// Lives below "أساتذتي" on the home. Shows a friendly greeting line, then
/// two clean mini-meters — تقدّمك (progress) and حضورك (attendance) — each
/// with its own accent and a textual qualifier (ممتاز / جيد / يحتاج متابعة)
/// so a parent reading over the student's shoulder can grasp the state
/// without needing to interpret the percentage.
class _ProgressAttendanceCard extends StatelessWidget {
  const _ProgressAttendanceCard({
    required this.name,
    required this.progress,
    required this.attendance,
  });
  final String name;
  final int progress, attendance;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final headline = name.isEmpty ? 'تقدّمك هذا الفصل' : 'تقدّم $name هذا الفصل';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8A00).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.insights_outlined, size: 16, color: Color(0xFFFF8A00)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 14),
        _LightMeter(
          label: 'تقدّمك الدراسي',
          value: progress,
          accent: const Color(0xFFFF8A00),
          icon: Icons.trending_up_rounded,
        ),
        const SizedBox(height: 12),
        _LightMeter(
          label: 'نسبة حضورك',
          value: attendance,
          accent: const Color(0xFF10B981),
          icon: Icons.event_available_outlined,
        ),
      ]),
    );
  }
}

class _LightMeter extends StatelessWidget {
  const _LightMeter({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });
  final String label;
  final int value;
  final Color accent;
  final IconData icon;

  String get _qualifier {
    if (value >= 85) return 'ممتاز';
    if (value >= 70) return 'جيد جداً';
    if (value >= 50) return 'جيد';
    if (value > 0)   return 'يحتاج متابعة';
    return 'لا توجد بيانات بعد';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = value.clamp(0, 100);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: accent),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('$v%',
            style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_qualifier,
              style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.bold)),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: v / 100,
          minHeight: 8,
          color: accent,
          backgroundColor: cs.surfaceContainerHighest,
        ),
      ),
    ]);
  }
}

class _NextItemCard extends StatelessWidget {
  const _NextItemCard({
    required this.title, required this.emptyText, required this.icon, required this.color,
    required this.countdown, this.primary, this.secondary,
  });
  final String title, emptyText, countdown;
  final IconData icon;
  final Color color;
  final String? primary, secondary;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEmpty = primary == null || primary!.isEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        Text(isEmpty ? emptyText : primary!,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                color: isEmpty ? cs.onSurfaceVariant : cs.onSurface)),
        if (!isEmpty && secondary != null && secondary!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(secondary!, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isEmpty ? cs.surfaceContainerHighest : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(isEmpty ? '—' : countdown,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: isEmpty ? cs.onSurfaceVariant : color)),
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.accent, required this.title, required this.subtitle, this.trailing, this.actionLabel, this.onAction});
  final IconData icon;
  final Color accent;
  final String title, subtitle;
  final Widget? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(width: 4, height: 32, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: accent),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ])),
      if (trailing != null) trailing!,
      if (actionLabel != null)
        TextButton(onPressed: onAction, child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(actionLabel!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_left, size: 16),
        ])),
    ]);
  }
}

/// Premium teacher card — large, photo-first, with status, course count,
/// and a quick "next session" line. Tap opens the workspace.
class _ProfessionalTeacherCard extends StatelessWidget {
  const _ProfessionalTeacherCard({required this.teacher, required this.onTap, required this.resolveImage});
  final _MyTeacher teacher;
  final VoidCallback onTap;
  final String Function(String?) resolveImage;
  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first;
    return parts.first.characters.first + parts.last.characters.first;
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = teacher.courses.any((c) => c.status == 'confirmed' || c.status == 'approved');
    final photoUrl = resolveImage(teacher.photo.isEmpty ? null : teacher.photo);
    final mainCourse = teacher.courses.isNotEmpty ? teacher.courses.first.name : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary.withValues(alpha: 0.06),
              cs.surface,
            ],
            begin: Alignment.topRight, end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row: photo + status badge
          Row(children: [
            Stack(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: isActive ? const Color(0xFF10B981) : cs.outlineVariant, width: 2),
                ),
                child: ClipOval(
                  child: photoUrl.isNotEmpty
                      ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _avatarFallback(cs))
                      : _avatarFallback(cs),
                ),
              ),
              if (isActive) Positioned(
                right: 0, bottom: 0,
                child: Container(width: 14, height: 14,
                  decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 2))),
              ),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.book_outlined, size: 11, color: cs.primary),
                const SizedBox(width: 3),
                Text('${teacher.courses.length}', style: TextStyle(color: cs.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Text('الأستاذ', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(teacher.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          if (mainCourse.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(mainCourse,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ],
          const Spacer(),
          // Quick action row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('فتح الصفحة',
                  style: TextStyle(color: cs.onPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_left, color: cs.onPrimary, size: 16),
            ]),
          ),
        ]),
      ),
    );
  }
  Widget _avatarFallback(ColorScheme cs) {
    return Container(
      color: cs.primary.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Text(_initials(teacher.name),
          style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 22)),
    );
  }
}

class _SuggestedTeacherTile extends StatelessWidget {
  const _SuggestedTeacherTile({required this.name, required this.photo, required this.onTap});
  final String name, photo;
  final VoidCallback onTap;
  String _initials(String n) => n.isEmpty ? '?' : n.characters.first;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            foregroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: Text(_initials(name),
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 22)),
          ),
          const SizedBox(height: 8),
          Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _SuggestedCourseTile extends StatelessWidget {
  const _SuggestedCourseTile({required this.name, required this.teacherName, required this.image, required this.onTap});
  final String name, teacherName, image;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: image.isNotEmpty
                  ? Image.network(image, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder(cs))
                  : _placeholder(cs),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              if (teacherName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(teacherName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
  Widget _placeholder(ColorScheme cs) => Container(
    color: cs.primary.withValues(alpha: 0.1),
    alignment: Alignment.center,
    child: Icon(Icons.school_outlined, size: 40, color: cs.primary.withValues(alpha: 0.5)),
  );
}

class _MutedEmpty extends StatelessWidget {
  const _MutedEmpty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(text, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
    );
  }
}

class _EmptyMyTeachers extends StatelessWidget {
  const _EmptyMyTeachers();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(children: [
        Icon(Icons.person_search_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        const Text('لم تنضم لأي أستاذ بعد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        Text('تصفّح المعلمين المقترحين بالأسفل واحجز كورسك الأول',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

/// Promo card on the student home — entry point into the Phase 10.1 VOD
/// catalog. Compact, ribbon-style, gradient background so it stands out
/// from the rest of the home without dominating it.
class _VideoCoursesPromo extends StatelessWidget {
  const _VideoCoursesPromo({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              cs.primary.withValues(alpha: 0.92),
              cs.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الدورات المرئية',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('شاهد دروسك متى وأينما شئت — بثّ HD على Bunny',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left, color: Colors.white),
        ]),
      ),
    );
  }
}
