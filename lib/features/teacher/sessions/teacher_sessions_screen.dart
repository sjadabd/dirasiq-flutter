import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import 'teacher_attendance_screen.dart';

/// Teacher → "الجدول الأسبوعي" — matched to الجدولLight/Dark.html.
///
/// Header + bottom nav follow the shared teacher chrome. Real data only
/// (`fetchSessions`): time, computed duration, title/course/grade, attendee
/// count, and a منتهية/جارية/قادمة status DERIVED from the session's weekday +
/// time vs. now. The mock's "room" isn't in the payload, so it's omitted (no
/// fabricated value). Tapping a session opens the attendance screen.
class TeacherSessionsScreen extends StatefulWidget {
  const TeacherSessionsScreen({super.key});
  @override
  State<TeacherSessionsScreen> createState() => _TeacherSessionsScreenState();
}

class _TeacherSessionsScreenState extends State<TeacherSessionsScreen> {
  final _api = TeacherApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  int _selIndex = 0; // 0..6 over the Sat→Fri strip
  String? _teacherId;

  // Display order (right→left in RTL): Saturday … Friday.
  static const _dayNames = [
    'السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'
  ];

  late DateTime _weekSat;
  late int _todayWeekday;

  // Baghdad wall-clock (UTC+3, no DST). Session start/end are stored as bare
  // TIME values in Baghdad time, so "now" must be anchored to the same zone —
  // otherwise a device on a different timezone mislabels the session status.
  DateTime _nowBaghdad() => DateTime.now().toUtc().add(const Duration(hours: 3));

  @override
  void initState() {
    super.initState();
    final now = _nowBaghdad();
    _todayWeekday = now.weekday % 7; // Mon=1..Sun=7 → Sun=0..Sat=6
    final today = DateTime(now.year, now.month, now.day);
    _weekSat = today.subtract(Duration(days: (now.weekday - DateTime.saturday) % 7));
    _selIndex = (_todayWeekday + 1) % 7; // index whose weekday == today
    _loadTeacherId();
    _fetch();
  }

  Future<void> _loadTeacherId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user');
      if (raw == null) return;
      final u = jsonDecode(raw) as Map<String, dynamic>;
      _teacherId = (u['id'] ?? u['_id'])?.toString();
    } catch (_) {}
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchSessions(page: 1, limit: 100);
      final list = res['data'];
      _items = (list is List)
          ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : [];
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب الجلسات',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSession(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('تأكيد الحذف'),
              content: const Text('سيتم حذف الجلسة. لا يمكن استرجاعها.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء')),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('حذف')),
              ],
            ));
    if (ok != true) return;
    try {
      await _api.deleteSession(s['id'].toString());
      Get.snackbar('تم', 'تم الحذف', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر الحذف', snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ---- add weekly schedule ------------------------------------------------

  // Backend weekday encoding: 0=Sun … 6=Sat.
  static const _schedDayLabels = [
    'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'
  ];

  String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String? _apiMessage(Object e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map && data['message'] is String) {
        final m = (data['message'] as String).trim();
        if (m.isNotEmpty) return m;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _showAddScheduleSheet() async {
    // Load the teacher's courses for the picker.
    List<Map<String, dynamic>> courses = [];
    try {
      final res = await _api.fetchCourses(limit: 100, deleted: false);
      final list = res['data'];
      courses = (list is List)
          ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : [];
    } catch (_) {}
    if (!mounted) return;
    if (courses.isEmpty) {
      Get.snackbar('تنبيه', 'لا توجد دورات — أنشئ دورة أولاً لإضافة جدول لها',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final titleCtl = TextEditingController();
    String? courseId = courses.first['id']?.toString();
    final Set<int> days = {};
    TimeOfDay? start;
    TimeOfDay? end;
    bool saving = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String courseName(Map c) =>
        (c['course_name'] ?? c['courseName'] ?? c['name'] ?? '—').toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Theme(
        data: isDark ? MqTheme.dark() : MqTheme.light(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(builder: (sheetCtx, setLocal) {
            final mq = sheetCtx.mq;

            Future<void> pickTime(bool isStart) async {
              final picked = await showTimePicker(
                context: sheetCtx,
                initialTime: isStart
                    ? (start ?? const TimeOfDay(hour: 16, minute: 0))
                    : (end ?? const TimeOfDay(hour: 17, minute: 0)),
              );
              if (picked != null) {
                setLocal(() => isStart ? start = picked : end = picked);
              }
            }

            Future<void> save() async {
              if (courseId == null || courseId!.isEmpty) {
                Get.snackbar('تنبيه', 'اختر الدورة',
                    snackPosition: SnackPosition.BOTTOM);
                return;
              }
              if (days.isEmpty) {
                Get.snackbar('تنبيه', 'اختر يوماً واحداً على الأقل',
                    snackPosition: SnackPosition.BOTTOM);
                return;
              }
              if (start == null || end == null) {
                Get.snackbar('تنبيه', 'حدّد وقت البداية والنهاية',
                    snackPosition: SnackPosition.BOTTOM);
                return;
              }
              final sMin = start!.hour * 60 + start!.minute;
              final eMin = end!.hour * 60 + end!.minute;
              if (eMin <= sMin) {
                Get.snackbar('تنبيه', 'وقت النهاية يجب أن يكون بعد البداية',
                    snackPosition: SnackPosition.BOTTOM);
                return;
              }
              setLocal(() => saving = true);
              try {
                final res = await _api.createSession({
                  'course_id': courseId,
                  'teacher_id': _teacherId,
                  'weekdays': days.toList()..sort(),
                  'start_time': _fmtTod(start!),
                  'end_time': _fmtTod(end!),
                  if (titleCtl.text.trim().isNotEmpty)
                    'title': titleCtl.text.trim(),
                  'recurrence': true,
                });
                final data = res['data'];
                final createdCount = (data is Map && data['created'] is List)
                    ? (data['created'] as List).length
                    : 0;
                final skipped = (data is Map && data['skipped'] is List)
                    ? (data['skipped'] as List)
                    : const [];
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                if (skipped.isNotEmpty) {
                  Get.snackbar(
                    'تم جزئياً',
                    'أُضيفت $createdCount جلسة، وتُخطّيت ${skipped.length} بسبب تعارض في الأوقات',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 4),
                  );
                } else {
                  Get.snackbar('تم', 'تمت إضافة الجدول الأسبوعي',
                      snackPosition: SnackPosition.BOTTOM);
                }
                await _fetch();
              } catch (e) {
                setLocal(() => saving = false);
                Get.snackbar('خطأ', _apiMessage(e) ?? 'تعذّرت إضافة الجدول',
                    snackPosition: SnackPosition.BOTTOM);
              }
            }

            Widget timeField(String label, TimeOfDay? value, bool isStart) {
              return Expanded(
                child: InkWell(
                  onTap: () => pickTime(isStart),
                  borderRadius: MqRadius.brMd,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: label,
                      isDense: true,
                      prefixIcon: const Icon(Icons.schedule_outlined),
                    ),
                    child: Text(value == null ? 'اختر' : _fmtTod(value),
                        style: sheetCtx.text.bodyMedium?.copyWith(
                            color: value == null ? mq.ink3 : mq.ink)),
                  ),
                ),
              );
            }

            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: mq.card,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(MqRadius.xl)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(MqSpacing.lg,
                        MqSpacing.sm, MqSpacing.lg, MqSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: MqSpacing.md),
                            decoration: BoxDecoration(
                                color: mq.line, borderRadius: MqRadius.brPill),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                  color: mq.accentSoft,
                                  borderRadius: MqRadius.brSm),
                              child: Icon(Icons.calendar_month_outlined,
                                  size: MqSize.iconSm, color: mq.accent),
                            ),
                            const SizedBox(width: MqSpacing.sm),
                            Expanded(
                              child: Text('إضافة جدول أسبوعي',
                                  style: sheetCtx.text.titleMedium),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(sheetCtx),
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child:
                                    Icon(Icons.close_rounded, color: mq.ink3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MqSpacing.lg),
                        DropdownButtonFormField<String>(
                          initialValue: courseId,
                          isExpanded: true,
                          dropdownColor: mq.card,
                          decoration: const InputDecoration(
                            labelText: 'الدورة',
                            prefixIcon: Icon(Icons.menu_book_outlined),
                            isDense: true,
                          ),
                          items: [
                            for (final c in courses)
                              DropdownMenuItem(
                                value: c['id']?.toString(),
                                child: Text(courseName(c),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) => setLocal(() => courseId = v),
                        ),
                        const SizedBox(height: MqSpacing.lg),
                        Text('أيام الأسبوع',
                            style: sheetCtx.text.labelMedium
                                ?.copyWith(color: mq.ink2)),
                        const SizedBox(height: MqSpacing.sm),
                        Wrap(
                          spacing: MqSpacing.sm,
                          runSpacing: MqSpacing.sm,
                          children: [
                            for (int i = 0; i < 7; i++)
                              MqChip(
                                label: _schedDayLabels[i],
                                selected: days.contains(i),
                                onTap: () => setLocal(() {
                                  if (days.contains(i)) {
                                    days.remove(i);
                                  } else {
                                    days.add(i);
                                  }
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: MqSpacing.lg),
                        Row(
                          children: [
                            timeField('من', start, true),
                            const SizedBox(width: MqSpacing.sm),
                            timeField('إلى', end, false),
                          ],
                        ),
                        const SizedBox(height: MqSpacing.md),
                        TextField(
                          controller: titleCtl,
                          decoration: const InputDecoration(
                            labelText: 'عنوان الحصة (اختياري)',
                            hintText: 'مثال: محاضرة الرياضيات',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: MqSpacing.xl),
                        MqButton(
                          label: saving ? 'جارٍ الحفظ…' : 'إضافة الجدول',
                          icon: saving ? null : Icons.check_rounded,
                          loading: saving,
                          onPressed: saving ? null : save,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), titleCtl.dispose);
  }

  // ---- derived ----

  int _weekdayOf(int index) => (DateTime.saturday + index) % 7; // Sat=6,Sun=0…
  DateTime _dateOf(int index) => _weekSat.add(Duration(days: index));

  // Minutes-from-midnight. Accepts raw 24h "HH:MM:SS" AND the API's friendly
  // 12h Arabic label ("1:10 مساءً" / "3:00 صباحاً") — the latter was being
  // mis-read as 1 AM, flipping ongoing/upcoming sessions to "منتهية".
  int _minutes(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return 0;
    final mt = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
    if (mt == null) return 0;
    var h = int.tryParse(mt.group(1)!) ?? 0;
    final m = int.tryParse(mt.group(2)!) ?? 0;
    final pm = s.contains('مساء') || s.toLowerCase().contains('pm');
    final am = s.contains('صباح') || s.toLowerCase().contains('am');
    if (pm && h < 12) h += 12;
    if (am && h == 12) h = 0;
    return h * 60 + m;
  }

  int _durationMin(Map s) {
    final d = _minutes(s['end_time']) - _minutes(s['start_time']);
    return d > 0 ? d : 0;
  }

  String _time(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return s;
    // The API may send a friendly 12h label ("1:10 مساءً"); compact it to
    // "1:10 م". Raw "HH:MM:SS" → "HH:MM".
    final pm = s.contains('مساء') || s.toLowerCase().contains('pm');
    final am = s.contains('صباح') || s.toLowerCase().contains('am');
    final mt = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s);
    if (mt != null && (pm || am)) {
      return '${mt.group(1)}:${mt.group(2)} ${pm ? 'م' : 'ص'}';
    }
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  List<Map<String, dynamic>> _sessionsOn(int weekday) {
    final list = _items
        .where((s) =>
            (s['weekday'] is num) && (s['weekday'] as num).toInt() == weekday)
        .toList();
    list.sort((a, b) => _minutes(a['start_time']).compareTo(_minutes(b['start_time'])));
    return list;
  }

  (String, TeacherTone) _status(Map s) {
    final selDate = _dateOf(_selIndex);
    final now = _nowBaghdad();
    final today = DateTime(now.year, now.month, now.day);
    if (selDate.isBefore(today)) return ('منتهية', TeacherTone.neutral);
    if (selDate.isAfter(today)) return ('قادمة', TeacherTone.info);
    // today → compare time
    final nowMin = now.hour * 60 + now.minute;
    final start = _minutes(s['start_time']);
    var end = _minutes(s['end_time']);
    // Missing/invalid end → assume a 60-min window so the session still passes
    // through "جارية" instead of jumping straight to "منتهية" at start.
    if (end <= start) end = start + 60;
    if (nowMin < start) return ('قادمة', TeacherTone.info);
    if (nowMin <= end) return ('جارية', TeacherTone.success);
    return ('منتهية', TeacherTone.neutral);
  }

  String _weekRange() {
    const months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    final fri = _dateOf(6);
    final sameMonth = _weekSat.month == fri.month;
    if (sameMonth) {
      return '${_weekSat.day} — ${fri.day} ${months[fri.month - 1]} ${fri.year}';
    }
    return '${_weekSat.day} ${months[_weekSat.month - 1]} — ${fri.day} ${months[fri.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          final selWeekday = _weekdayOf(_selIndex);
          final daySessions = _sessionsOn(selWeekday);
          final totalMin = _items.fold<int>(0, (a, s) => a + _durationMin(s));
          final todayCount = _sessionsOn(_todayWeekday).length;

          return Scaffold(
            backgroundColor: mq.page,
            appBar: TeacherAppBar(
              title: 'الجدول الأسبوعي',
              actions: [_RefreshAction(loading: _loading, onTap: _fetch)],
            ),
            drawer: const TeacherDrawer(),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _showAddScheduleSheet,
              backgroundColor: mq.accent,
              foregroundColor: mq.onAccent,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة جدول'),
            ),
            body: RefreshIndicator(
              onRefresh: _fetch,
              color: mq.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, 96),
                children: [
                  _hero(context, totalMin, todayCount),
                  const SizedBox(height: MqSpacing.lg),
                  _weekStrip(context),
                  const SizedBox(height: MqSpacing.lg),
                  _dayHeader(context, selWeekday, daySessions.length),
                  const SizedBox(height: MqSpacing.sm),
                  if (_loading && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(MqSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (daySessions.isEmpty)
                    _emptyDay(context)
                  else
                    ...daySessions.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: MqSpacing.sm),
                          child: _SessionCard(
                            session: s,
                            time: _time(s['start_time']),
                            endTime: _time(s['end_time']),
                            durationMin: _durationMin(s),
                            status: _status(s),
                            onTap: () => Get.to(() => TeacherAttendanceScreen(
                                sessionId: s['id'].toString(),
                                session: s,
                                initialDate: _dateOf(_selIndex))),
                            onDelete: () => _deleteSession(s),
                          ),
                        )),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _hero(BuildContext context, int totalMin, int todayCount) {
    final t = context.teacher;
    final hours = (totalMin / 60).round();
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: context.mq.orange, shape: BoxShape.circle),
                child: const Icon(Icons.calendar_today_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الجدول الأسبوعي',
                        style:
                            context.text.titleMedium?.copyWith(color: t.heroInk)),
                    const SizedBox(height: 2),
                    Text(_weekRange(),
                        style:
                            context.text.labelSmall?.copyWith(color: t.heroInk2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MqSpacing.lg),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heroStat(context, '${_items.length}', 'حصص الأسبوع'),
                const SizedBox(width: MqSpacing.sm),
                _heroStat(context, '$hours', 'ساعات'),
                const SizedBox(width: MqSpacing.sm),
                _heroStat(context, '$todayCount', 'اليوم'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(BuildContext context, String value, String label) {
    final t = context.teacher;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.sm, vertical: MqSpacing.sm),
        decoration: BoxDecoration(
          color: t.heroTile,
          borderRadius: MqRadius.brMd,
          border: Border.all(color: t.heroLine),
        ),
        child: Column(
          children: [
            Text(value,
                style: MqTypography.mono(
                    color: t.heroInk, size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: t.heroInk2)),
          ],
        ),
      ),
    );
  }

  Widget _weekStrip(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < 7; i++) ...[
          _DayCell(
            name: _dayNames[i],
            date: _dateOf(i).day,
            count: _sessionsOn(_weekdayOf(i)).length,
            selected: _selIndex == i,
            isToday: _weekdayOf(i) == _todayWeekday,
            onTap: () => setState(() => _selIndex = i),
          ),
          if (i < 6) const SizedBox(width: MqSpacing.xs),
        ],
      ],
    );
  }

  Widget _dayHeader(BuildContext context, int weekday, int count) {
    final mq = context.mq;
    final idx = (weekday + 1) % 7; // strip index for name
    final name = _dayNames[idx];
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration:
              BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brSm),
          child: Icon(Icons.event_note_outlined,
              size: MqSize.iconSm, color: mq.accent),
        ),
        const SizedBox(width: MqSpacing.sm),
        Text('حصص $name', style: context.text.titleSmall),
        const Spacer(),
        Text(
            count > 0 ? '$count حصص مجدولة' : 'لا حصص',
            style: context.text.labelSmall?.copyWith(color: mq.ink3)),
      ],
    );
  }

  Widget _emptyDay(BuildContext context) {
    final mq = context.mq;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: mq.fill2, shape: BoxShape.circle),
            child: Icon(Icons.event_busy_outlined, size: 30, color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.md),
          Text('لا توجد حصص في هذا اليوم',
              style: context.text.bodyMedium?.copyWith(color: mq.ink2)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _RefreshAction extends StatelessWidget {
  const _RefreshAction({required this.loading, required this.onTap});
  final bool loading;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MqSpacing.xs),
      child: Material(
        color: mq.fill,
        shape: RoundedRectangleBorder(
          borderRadius: MqRadius.brMd,
          side: BorderSide(color: mq.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : () => onTap(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: loading
                ? Padding(
                    padding: const EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: mq.ink3),
                  )
                : Icon(Icons.refresh_rounded,
                    size: MqSize.iconSm, color: mq.ink2),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.name,
    required this.date,
    required this.count,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });
  final String name;
  final int date;
  final int count;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final fg = selected ? mq.onAccent : (isToday ? mq.accent : mq.ink2);
    final bg = selected ? mq.accent : mq.card;
    final border = selected
        ? mq.accent
        : (isToday ? mq.accentLine : mq.line);

    return Expanded(
      child: InkWell(
        borderRadius: MqRadius.brMd,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: MqRadius.brMd,
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(name,
                    style: context.text.labelSmall?.copyWith(
                        color: selected ? mq.onAccent : mq.ink3,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 3),
              Text('$date',
                  style: MqTypography.mono(
                      color: fg, size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              if (count > 0)
                Container(
                  width: 18,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? mq.onAccent.withValues(alpha: 0.25) : mq.accentSoft,
                    borderRadius: MqRadius.brPill,
                  ),
                  child: Text('$count',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: selected ? mq.onAccent : mq.accent)),
                )
              else
                Text('—',
                    style: context.text.labelSmall?.copyWith(
                        color: selected ? mq.onAccent.withValues(alpha: 0.6) : mq.ink3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.time,
    required this.endTime,
    required this.durationMin,
    required this.status,
    required this.onTap,
    required this.onDelete,
  });
  final Map<String, dynamic> session;
  final String time;
  final String endTime;
  final int durationMin;
  final (String, TeacherTone) status;
  final VoidCallback onTap, onDelete;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final s = session;
    final title = (s['title'] ?? s['course_name'] ?? 'حصة').toString();
    final course = (s['course_name'] ?? '').toString();
    final grade = (s['grade_name'] ?? '').toString();
    final sub = [course, grade].where((x) => x.isNotEmpty).toSet().join(' · ');
    final attendees = s['attendees_count'];
    final (statusLabel, statusTone) = status;
    final ended = statusLabel == 'منتهية';

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // time block
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
                decoration: BoxDecoration(
                  color: mq.accentSoft,
                  borderRadius: MqRadius.brSm,
                  border: Border.all(color: mq.accentLine),
                ),
                child: Column(
                  children: [
                    Text(time,
                        style: MqTypography.mono(
                            color: mq.accent, size: 14, weight: FontWeight.w700)),
                    if (durationMin > 0)
                      Text('$durationMin د',
                          style: context.text.labelSmall
                              ?.copyWith(color: mq.ink3)),
                  ],
                ),
              ),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (sub.isNotEmpty)
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall
                              ?.copyWith(color: mq.ink3)),
                  ],
                ),
              ),
              const SizedBox(width: MqSpacing.sm),
              TeacherStatusPill(label: statusLabel, tone: statusTone),
            ],
          ),
          const SizedBox(height: MqSpacing.sm),
          Row(
            children: [
              Icon(Icons.group_outlined, size: 14, color: context.teacher.success),
              const SizedBox(width: MqSpacing.xs),
              Text('${attendees ?? 0} طالب',
                  style: context.text.labelSmall?.copyWith(
                      color: context.teacher.success,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              // Tappable for any day — ended sessions open for editing past
              // attendance (absent → leave / present).
              Icon(Icons.fact_check_outlined, size: 15, color: mq.accent),
              const SizedBox(width: MqSpacing.xs),
              Text(ended ? 'تعديل الحضور' : 'تسجيل الحضور',
                  style: context.text.labelSmall?.copyWith(
                      color: mq.accent, fontWeight: FontWeight.w600)),
              const SizedBox(width: MqSpacing.sm),
              InkWell(
                onTap: onDelete,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 18, color: mq.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
