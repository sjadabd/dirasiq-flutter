// Student → Weekly schedule / timetable (MulhimIQ design-system pass).
//
// Backend: ApiService.fetchWeeklyScheduleByCourse(courseId) → rows with
// { courseName, teacherName, title, weekday, startTime, endTime, startAt,
//   endAt, state, flexType }. NO change to the endpoint or schedule logic.
//
// Weekday mapping (confirmed against the backend): the API's `weekday` is
// Postgres `EXTRACT(DOW)` → 0 = Sunday … 6 = Saturday. The Arabic day strip
// therefore starts at الأحد (index 0). No shift is applied. startTime/endTime
// already arrive as 12-hour strings ("3:30 PM"); only the AM/PM suffix is
// localised for display. startAt/endAt are real ISO datetimes for THIS week,
// used to derive the اليوم / قادم / منتهي status accurately.

import 'package:flutter/material.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class CourseWeeklyScheduleScreen extends StatefulWidget {
  final String courseId;
  final String? courseName;

  const CourseWeeklyScheduleScreen({
    super.key,
    required this.courseId,
    this.courseName,
  });

  @override
  State<CourseWeeklyScheduleScreen> createState() =>
      _CourseWeeklyScheduleScreenState();
}

class _CourseWeeklyScheduleScreenState
    extends State<CourseWeeklyScheduleScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  // Sunday = 0 … Saturday = 6 (matches backend EXTRACT(DOW)).
  static const List<String> _arWeekday = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
  ];

  int _selectedDay = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().weekday % 7; // Dart Sun=7 → 0; Mon=1 → 1 …
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.fetchWeeklyScheduleByCourse(widget.courseId);
      list.sort((a, b) {
        final wa = _weekdayOf(a);
        final wb = _weekdayOf(b);
        if (wa != wb) return wa.compareTo(wb);
        final sa = (a['startAt'] ?? a['startTime'] ?? '').toString();
        final sb = (b['startAt'] ?? b['startTime'] ?? '').toString();
        return sa.compareTo(sb);
      });
      setState(() {
        _items = list;
        _loading = false;
        _selectedDay = _defaultDay(list);
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// Land on a day that actually has lectures: today if it has any, otherwise
  /// the nearest upcoming day (wrapping the week), otherwise day 0. Avoids the
  /// "empty screen" when today happens to carry no session for this course.
  int _defaultDay(List<Map<String, dynamic>> list) {
    final counts = <int, int>{};
    for (final s in list) {
      final d = _weekdayOf(s);
      counts[d] = (counts[d] ?? 0) + 1;
    }
    if (counts.isEmpty) return DateTime.now().weekday % 7;
    final today = DateTime.now().weekday % 7;
    for (var i = 0; i < 7; i++) {
      final d = (today + i) % 7;
      if ((counts[d] ?? 0) > 0) return d;
    }
    return today;
  }

  int _weekdayOf(Map<String, dynamic> s) {
    final raw = s['weekday'] ?? s['day_of_week'] ?? s['dayOfWeek'] ?? 0;
    final v = (raw is int) ? raw : int.tryParse(raw.toString()) ?? 0;
    return (v >= 0 && v <= 6) ? v : 0;
  }

  List<Map<String, dynamic>> get _selectedItems =>
      _items.where((s) => _weekdayOf(s) == _selectedDay).toList();

  Map<int, int> get _countsByDay {
    final m = <int, int>{};
    for (final s in _items) {
      final d = _weekdayOf(s);
      m[d] = (m[d] ?? 0) + 1;
    }
    return m;
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();

    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.mq.page,
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('الجدول الأسبوعي'),
                  Text('محاضراتك ودروسك خلال الأسبوع',
                      style: context.text.bodySmall),
                ],
              ),
            ),
            body: RefreshIndicator(onRefresh: _fetch, child: _body(context)),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return _skeleton(context);
    if (_error != null) return _errorView(context);
    if (_items.isEmpty) {
      return _weekEmpty(context);
    }

    final counts = _countsByDay;
    final dayItems = _selectedItems;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxxl),
      children: [
        if ((widget.courseName?.trim().isNotEmpty ?? false)) ...[
          Row(
            children: [
              Icon(Icons.menu_book_outlined,
                  size: MqSize.iconSm, color: context.mq.accent),
              MqSpacing.gapXs,
              Expanded(
                child: Text(widget.courseName!,
                    style: context.text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          MqSpacing.gapMd,
        ],
        _summary(context),
        MqSpacing.gapLg,
        _daySelector(context, counts),
        MqSpacing.gapLg,
        if (dayItems.isEmpty)
          _dayEmpty(context)
        else
          for (final s in dayItems)
            Padding(
              padding: const EdgeInsets.only(bottom: MqSpacing.sm),
              child: _lectureCard(context, s),
            ),
      ],
    );
  }

  // ── summary cards ───────────────────────────────────────────────────────────

  Widget _summary(BuildContext context) {
    final m = context.mq;
    final total = _items.length;
    final todayIdx = DateTime.now().weekday % 7;
    final todayCount = _countsByDay[todayIdx] ?? 0;
    final next = _nextLecture();

    final cards = <Widget>[
      Expanded(
        child: _summaryCard(context, '$total', 'محاضرات هذا الأسبوع',
            m.accent, Icons.calendar_month_outlined),
      ),
      MqSpacing.gapSm,
      Expanded(
        child: _summaryCard(context, '$todayCount', 'محاضرات اليوم',
            m.success, Icons.today_outlined),
      ),
    ];
    if (next != null) {
      cards
        ..add(MqSpacing.gapSm)
        ..add(Expanded(
          child: _summaryCard(context, next, 'أقرب محاضرة', m.orange,
              Icons.upcoming_outlined),
        ));
    }
    // crossAxisAlignment.start (NOT stretch): inside the outer ListView the row
    // gets an unbounded height, and `stretch` would force an infinite height on
    // the cards — that pushed the day selector + lectures off-screen, leaving a
    // blank schedule. Cards size to their own content instead.
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: cards);
  }

  Widget _summaryCard(BuildContext context, String value, String label,
      Color color, IconData icon) {
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: MqSize.iconMd),
          MqSpacing.gapXs,
          Text(value,
              style: context.text.titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: context.text.labelSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  /// Nearest upcoming lecture label ("الأحد • 3:30 م"), or null if none ahead.
  String? _nextLecture() {
    final now = DateTime.now();
    DateTime? best;
    Map<String, dynamic>? bestSlot;
    for (final s in _items) {
      final start = _tryDate(s['startAt']);
      if (start == null || start.isBefore(now)) continue;
      if (best == null || start.isBefore(best)) {
        best = start;
        bestSlot = s;
      }
    }
    if (bestSlot == null) return null;
    final day = _arWeekday[_weekdayOf(bestSlot)];
    final time = _ar12(bestSlot['startTime']);
    return time.isEmpty ? day : '$day • $time';
  }

  // ── day selector ────────────────────────────────────────────────────────────

  Widget _daySelector(BuildContext context, Map<int, int> counts) {
    // A plain horizontal scroller (not a nested ListView) — robust inside the
    // outer vertical ListView under RTL + RefreshIndicator.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: MqSpacing.xs),
            _dayPill(context, i, counts[i] ?? 0),
          ],
        ],
      ),
    );
  }

  Widget _dayPill(BuildContext context, int index, int count) {
    final m = context.mq;
    final selected = index == _selectedDay;
    final bg = selected ? m.accent : m.fill;
    final fg = selected ? m.onAccent : m.ink2;
    final border = selected ? m.accent : m.line;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: MqRadius.brLg,
        side: BorderSide(color: border, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedDay = index),
        child: Container(
          width: 62,
          padding: const EdgeInsets.symmetric(horizontal: MqSpacing.xs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_arWeekday[index],
                  style: context.text.labelMedium?.copyWith(
                      color: fg,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? m.onAccent.withValues(alpha: 0.22)
                        : m.accentSoft,
                    borderRadius: MqRadius.brPill,
                  ),
                  child: Text('$count',
                      style: context.text.labelSmall?.copyWith(
                          color: selected ? m.onAccent : m.accent,
                          fontWeight: FontWeight.w700)),
                )
              else
                Text('—',
                    style: context.text.labelSmall
                        ?.copyWith(color: fg.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ),
    );
  }

  // ── lecture card ────────────────────────────────────────────────────────────

  Widget _lectureCard(BuildContext context, Map<String, dynamic> s) {
    final m = context.mq;
    final courseName = (s['courseName'] ?? widget.courseName ?? '').toString();
    final title = (s['title'] ?? '').toString();
    final teacher = (s['teacherName'] ?? '').toString();
    final start = _ar12(s['startTime']);
    final end = _ar12(s['endTime']);

    final status = _statusOf(s); // null | today | upcoming | past
    final (String? statusLabel, MqBadgeTone statusTone) = switch (status) {
      'today' => ('اليوم', MqBadgeTone.success),
      'upcoming' => ('قادم', MqBadgeTone.accent),
      'past' => ('منتهي', MqBadgeTone.neutral),
      _ => (null, MqBadgeTone.neutral),
    };

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: m.accentSoft, borderRadius: MqRadius.brMd),
                child: Icon(Icons.schedule_rounded,
                    color: m.accent, size: MqSize.iconMd),
              ),
              MqSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        courseName.isNotEmpty
                            ? courseName
                            : (title.isNotEmpty ? title : 'محاضرة'),
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (title.isNotEmpty && title != courseName) ...[
                      const SizedBox(height: 2),
                      Text(title,
                          style: context.text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              if (statusLabel != null) ...[
                MqSpacing.gapSm,
                MqBadge(label: statusLabel, tone: statusTone),
              ],
            ],
          ),
          MqSpacing.gapSm,
          Row(
            children: [
              if (start.isNotEmpty || end.isNotEmpty) ...[
                Icon(Icons.access_time_rounded, size: 13, color: m.ink3),
                MqSpacing.gapXxs,
                Text(
                    start.isNotEmpty && end.isNotEmpty
                        ? '$start - $end'
                        : (start.isNotEmpty ? start : end),
                    style: context.text.labelSmall),
              ],
              if (teacher.isNotEmpty) ...[
                MqSpacing.gapMd,
                Icon(Icons.person_outline_rounded, size: 13, color: m.ink3),
                MqSpacing.gapXxs,
                Expanded(
                  child: Text(teacher,
                      style: context.text.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ] else
                const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  String? _statusOf(Map<String, dynamic> s) {
    final start = _tryDate(s['startAt']);
    final end = _tryDate(s['endAt']);
    if (start == null && end == null) return null;
    final now = DateTime.now();
    if (end != null && end.isBefore(now)) return 'past';
    if (start != null) {
      final today = DateTime(now.year, now.month, now.day);
      final sDay = DateTime(start.year, start.month, start.day);
      if (sDay == today) return 'today';
      return 'upcoming';
    }
    return null;
  }

  // ── states ──────────────────────────────────────────────────────────────────

  Widget _dayEmpty(BuildContext context) {
    final m = context.mq;
    return MqCard(
      padding: const EdgeInsets.symmetric(
          vertical: MqSpacing.xl, horizontal: MqSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available_outlined, size: 40, color: m.ink3),
          MqSpacing.gapSm,
          Text('لا توجد محاضرات في هذا اليوم',
              style: context.text.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _weekEmpty(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(MqSpacing.lg),
                decoration:
                    BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
                child: Icon(Icons.calendar_today_outlined,
                    size: 44, color: m.accent),
              ),
              MqSpacing.gapMd,
              Text('لا يوجد جدول معتمد بعد', style: context.text.titleMedium),
              MqSpacing.gapXs,
              Text('سيظهر هنا جدول محاضراتك الأسبوعي بمجرد اعتماده.',
                  textAlign: TextAlign.center, style: context.text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorView(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 44, color: m.error),
              MqSpacing.gapMd,
              Text(_error ?? 'حدث خطأ',
                  textAlign: TextAlign.center, style: context.text.bodyMedium),
              MqSpacing.gapMd,
              MqButton(
                  label: 'إعادة المحاولة',
                  icon: Icons.refresh_rounded,
                  expand: false,
                  onPressed: _fetch),
            ],
          ),
        ),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    Widget box(double h, {double? w}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: m.fill2, borderRadius: MqRadius.brLg));
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        Row(children: [
          Expanded(child: box(72)),
          MqSpacing.gapSm,
          Expanded(child: box(72)),
          MqSpacing.gapSm,
          Expanded(child: box(72)),
        ]),
        MqSpacing.gapLg,
        Row(
          children: List.generate(
              5,
              (i) => Padding(
                    padding: const EdgeInsets.only(left: MqSpacing.xs),
                    child: box(60, w: 62),
                  )),
        ),
        MqSpacing.gapLg,
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.sm),
            child: MqCard(
              padding: const EdgeInsets.all(MqSpacing.md),
              child: Row(children: [
                Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: m.fill2, borderRadius: MqRadius.brMd)),
                MqSpacing.gapMd,
                Expanded(
                    child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                            color: m.fill2, borderRadius: MqRadius.brSm))),
              ]),
            ),
          ),
      ],
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  DateTime? _tryDate(dynamic v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Localises the English AM/PM suffix on the backend's 12-hour strings.
  String _ar12(dynamic v) {
    final s = v?.toString().trim() ?? '';
    if (s.isEmpty) return '';
    return s
        .replaceAll('AM', 'ص')
        .replaceAll('PM', 'م')
        .replaceAll('am', 'ص')
        .replaceAll('pm', 'م');
  }
}
