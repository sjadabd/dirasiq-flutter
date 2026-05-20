import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_bottom_nav.dart';
import '../shared/teacher_helpers.dart';
import 'teacher_attendance_screen.dart';

/// Teacher → "الجدول الأسبوعي" (manage-sessions.vue).
class TeacherSessionsScreen extends StatefulWidget {
  const TeacherSessionsScreen({super.key});
  @override
  State<TeacherSessionsScreen> createState() => _TeacherSessionsScreenState();
}

class _TeacherSessionsScreenState extends State<TeacherSessionsScreen> {
  final _api = TeacherApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  int? _weekdayFilter;

  static const _days = [
    {'value': 0, 'label': 'الأحد'},
    {'value': 1, 'label': 'الاثنين'},
    {'value': 2, 'label': 'الثلاثاء'},
    {'value': 3, 'label': 'الأربعاء'},
    {'value': 4, 'label': 'الخميس'},
    {'value': 5, 'label': 'الجمعة'},
    {'value': 6, 'label': 'السبت'},
  ];

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchSessions(weekday: _weekdayFilter, page: 1, limit: 100);
      final list = res['data'];
      _items = (list is List) ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : [];
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب الجلسات', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSession(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: const Text('سيتم حذف الجلسة. لا يمكن استرجاعها.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.deleteSession(s['id'].toString());
      Get.snackbar('تم', 'تم الحذف', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) { Get.snackbar('خطأ', 'تعذّر الحذف', snackPosition: SnackPosition.BOTTOM); }
  }

  String _dayLabel(int? d) {
    if (d == null) return '—';
    return _days.firstWhere((x) => x['value'] == d, orElse: () => {'label': '—'})['label'] as String;
  }

  int get _todayWeekday {
    final d = DateTime.now().weekday; // Mon=1..Sun=7
    return d % 7; // → Sun=0, Mon=1...
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = _todayWeekday;
    final todayCount = _items.where((s) => (s['weekday'] is num) && (s['weekday'] as num).toInt() == today).length;
    // Group by weekday
    final byDay = <int, List<Map<String, dynamic>>>{};
    for (final s in _items) {
      final w = (s['weekday'] is num) ? (s['weekday'] as num).toInt() : -1;
      if (w < 0) continue;
      byDay.putIfAbsent(w, () => []).add(s);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => (a['start_time_24h'] ?? a['start_time'] ?? '').toString().compareTo((b['start_time_24h'] ?? b['start_time'] ?? '').toString()));
    }

    final dayOrder = [for (int i = 0; i < 7; i++) (today + i) % 7];

    return Scaffold(
      appBar: AppBar(
        title: const Text('الجدول الأسبوعي'),
        actions: [IconButton(onPressed: _loading ? null : _fetch, icon: const Icon(Icons.refresh))],
      ),
      drawer: const TeacherDrawer(),
      bottomNavigationBar: const TeacherBottomNav(),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
          TeacherHero(title: 'جدولي الأسبوعي', subtitle: 'اليوم: ${_dayLabel(today)} · $todayCount جلسة',
              icon: Icons.calendar_today_outlined),
          const SizedBox(height: 16),

          SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
            Padding(padding: const EdgeInsets.only(left: 8),
              child: StatusChip(label: 'الكل', selected: _weekdayFilter == null,
                  onTap: () { setState(() => _weekdayFilter = null); _fetch(); }, color: kNavy),
            ),
            for (final d in _days) Padding(padding: const EdgeInsets.only(left: 8),
              child: StatusChip(label: d['label'] as String, selected: _weekdayFilter == d['value'],
                  onTap: () { setState(() => _weekdayFilter = d['value'] as int); _fetch(); },
                  color: (d['value'] as int) == today ? kOrange : kSky),
            ),
          ])),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_items.isEmpty)
            const EmptyState(message: 'لا توجد جلسات. أنشئ جلستك الأولى من لوحة التحكم.')
          else for (final w in dayOrder)
            if ((byDay[w] ?? []).isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Row(children: [
                  Container(width: 4, height: 18, color: w == today ? kOrange : kNavy),
                  const SizedBox(width: 8),
                  Text(_dayLabel(w), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: w == today ? kOrange : cs.onSurface)),
                  if (w == today) const Padding(padding: EdgeInsets.only(right: 8),
                    child: Text('اليوم', style: TextStyle(fontSize: 10, color: kOrange))),
                  const Spacer(),
                  Text('${byDay[w]!.length} جلسة', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ]),
              ),
              for (final s in byDay[w]!) _SessionTile(
                session: s,
                onAttendance: () => Get.to(() => TeacherAttendanceScreen(sessionId: s['id'].toString(), session: s)),
                onDelete: () => _deleteSession(s),
              ),
            ],
        ]),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onAttendance, required this.onDelete});
  final Map<String, dynamic> session;
  final VoidCallback onAttendance, onDelete;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = (session['title'] ?? session['course_name'] ?? 'جلسة').toString();
    final course = (session['course_name'] ?? '').toString();
    final grade = (session['grade_name'] ?? '').toString();
    final start = (session['start_time'] ?? '').toString();
    final end = (session['end_time'] ?? '').toString();
    final attendees = session['attendees_count'];
    final state = (session['state'] ?? '').toString();
    final isConfirmed = state == 'confirmed';
    return InkWell(
      onTap: onAttendance,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isConfirmed ? kSky.withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.4))),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: kSky.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Text(start, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kSky)),
              Container(height: 1, width: 30, color: kSky.withValues(alpha: 0.4), margin: const EdgeInsets.symmetric(vertical: 2)),
              Text(end, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(course.isEmpty ? '—' : course, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (grade.isNotEmpty) Text(grade, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.group_outlined, size: 12, color: Colors.green),
              const SizedBox(width: 4),
              Text('${attendees ?? 0} طالب', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              const Icon(Icons.fact_check_outlined, size: 12, color: kOrange),
              const SizedBox(width: 4),
              const Text('تسجيل حضور', style: TextStyle(fontSize: 11, color: kOrange, fontWeight: FontWeight.w600)),
            ]),
          ])),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              visualDensity: VisualDensity.compact),
        ]),
      ),
    );
  }
}
