// Student → Course attendance history (MulhimIQ design-system pass).
//
// Backed by the existing endpoint ApiService.fetchMyAttendanceByCourse(courseId)
// — no backend change. Records carry: status (present / absent / leave),
// occurred date, check-in time, session title, notes/reason. They do NOT carry
// teacher name or a separate course name (the course is the screen's context),
// and there is no "late" status — so a متأخر filter/summary is omitted.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/core/utils/time_format.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class CourseAttendanceScreen extends StatefulWidget {
  final String courseId;
  final String? courseName;

  const CourseAttendanceScreen({
    super.key,
    required this.courseId,
    this.courseName,
  });

  @override
  State<CourseAttendanceScreen> createState() => _CourseAttendanceScreenState();
}

class _CourseAttendanceScreenState extends State<CourseAttendanceScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _filter = 'all'; // all, present, absent, leave

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.fetchMyAttendanceByCourse(widget.courseId);
      final dynamic rawItems =
          res['items'] ??
          res['records'] ??
          res['attendance'] ??
          res['data'] ??
          res;
      final list = (rawItems is List) ? rawItems : [];
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          list.map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'تعذّر تحميل سجل الحضور';
        _loading = false;
      });
    }
  }

  // ── status / counts / filters (logic preserved) ────────────────────────────

  String _statusKey(Map<String, dynamic> r) {
    final s = (r['status'] ?? r['attendanceStatus'] ?? r['type'] ?? '')
        .toString()
        .toLowerCase();
    if (s.contains('present') || s == 'حضور' || s == 'presented')
      return 'present';
    if (s.contains('absent') || s == 'غياب') return 'absent';
    if (s.contains('leave') || s == 'اجازة' || s == 'إجازة') return 'leave';
    return 'other';
  }

  Map<String, int> _computeCounts() {
    int present = 0, absent = 0, leave = 0;
    for (final r in _items) {
      switch (_statusKey(r)) {
        case 'present':
          present++;
        case 'absent':
          absent++;
        case 'leave':
          leave++;
      }
    }
    return {
      'total': _items.length,
      'present': present,
      'absent': absent,
      'leave': leave,
    };
  }

  List<Map<String, dynamic>> _filteredItems() {
    final list = _filter == 'all'
        ? _items
        : _items.where((r) => _statusKey(r) == _filter).toList();
    final copy = [...list];
    copy.sort(
      (a, b) => _parseDate(_dateOf(b)).compareTo(_parseDate(_dateOf(a))),
    );
    return copy;
  }

  dynamic _dateOf(Map<String, dynamic> r) =>
      r['checkin_at'] ??
      r['occurred_on'] ??
      r['date'] ??
      r['sessionDate'] ??
      r['createdAt'];

  DateTime _parseDate(dynamic v) {
    try {
      if (v == null) return DateTime.fromMicrosecondsSinceEpoch(0);
      return DateTime.parse(v.toString());
    } catch (_) {
      return DateTime.fromMicrosecondsSinceEpoch(0);
    }
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
              title: const Text('سجل الحضور'),
              bottom: (widget.courseName?.trim().isNotEmpty ?? false)
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(20),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: MqSpacing.sm),
                        child: Text(
                          widget.courseName!,
                          style: context.text.bodySmall,
                        ),
                      ),
                    )
                  : null,
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
    if (_items.isEmpty)
      return _empty(
        context,
        'لا توجد سجلات حضور بعد',
        'سيظهر هنا سجل حضورك وغيابك في هذه الدورة.',
      );

    final c = _computeCounts();
    final filtered = _filteredItems();
    final total = c['total'] ?? 0;
    final present = c['present'] ?? 0;
    final pct = total > 0 ? (present / total * 100).round() : 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        MqSpacing.lg,
        MqSpacing.lg,
        MqSpacing.lg,
        MqSpacing.xxxl,
      ),
      children: [
        // Summary
        Row(
          children: [
            Expanded(
              child: _summary(
                context,
                '$pct%',
                'نسبة الحضور',
                mq(context).accent,
                Icons.insights_outlined,
              ),
            ),
            MqSpacing.gapSm,
            Expanded(
              child: _summary(
                context,
                '$present',
                'حضور',
                mq(context).success,
                Icons.check_circle_outline,
              ),
            ),
            MqSpacing.gapSm,
            Expanded(
              child: _summary(
                context,
                '${c['absent']}',
                'غياب',
                mq(context).error,
                Icons.cancel_outlined,
              ),
            ),
            if ((c['leave'] ?? 0) > 0) ...[
              MqSpacing.gapSm,
              Expanded(
                child: _summary(
                  context,
                  '${c['leave']}',
                  'إجازة',
                  mq(context).orange,
                  Icons.event_busy_outlined,
                ),
              ),
            ],
          ],
        ),
        MqSpacing.gapLg,
        // Filters
        SizedBox(
          height: MqSize.chipHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip(context, 'all', 'الكل'),
              const SizedBox(width: MqSpacing.xs),
              _chip(context, 'present', 'حاضر'),
              const SizedBox(width: MqSpacing.xs),
              _chip(context, 'absent', 'غائب'),
              if ((c['leave'] ?? 0) > 0) ...[
                const SizedBox(width: MqSpacing.xs),
                _chip(context, 'leave', 'إجازة'),
              ],
            ],
          ),
        ),
        MqSpacing.gapMd,
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: MqSpacing.xl),
            child: Center(
              child: Text(
                'لا توجد سجلات لهذه الحالة',
                style: context.text.bodySmall,
              ),
            ),
          )
        else
          for (final r in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: MqSpacing.sm),
              child: _recordCard(context, r),
            ),
      ],
    );
  }

  MqColors mq(BuildContext context) => context.mq;

  Widget _summary(
    BuildContext context,
    String value,
    String label,
    Color color,
    IconData icon,
  ) {
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: MqSize.iconMd),
          MqSpacing.gapXs,
          Text(
            value,
            style: MqTypography.mono(
              color: color,
              size: 18,
              weight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: context.text.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String key, String label) {
    return MqChip(
      label: label,
      selected: _filter == key,
      onTap: () => setState(() => _filter = key),
    );
  }

  Widget _recordCard(BuildContext context, Map<String, dynamic> r) {
    final m = context.mq;
    final key = _statusKey(r);
    final (
      String label,
      IconData icon,
      Color color,
      MqBadgeTone tone,
    ) = switch (key) {
      'present' => (
        'حضور',
        Icons.check_circle_outline,
        m.success,
        MqBadgeTone.success,
      ),
      'absent' => ('غياب', Icons.cancel_outlined, m.error, MqBadgeTone.error),
      'leave' => (
        'إجازة',
        Icons.event_busy_outlined,
        m.orange,
        MqBadgeTone.orange,
      ),
      _ => (
        'غير محدد',
        Icons.help_outline_rounded,
        m.ink3,
        MqBadgeTone.neutral,
      ),
    };

    final occurred = _fmtDay(
      r['occurred_on'] ?? r['date'] ?? r['sessionDate'] ?? r['createdAt'],
    );
    final checkin12h = r['checkin_at_12h']?.toString();
    final checkin = formatTime12(
      (checkin12h != null && checkin12h.isNotEmpty)
          ? checkin12h
          : r['checkin_at'],
    );
    final sessionTitle =
        (r['sessionTitle'] ?? r['title'] ?? r['session']?['title'] ?? '')
            .toString();
    final notes = (r['notes'] ?? r['reason'] ?? '').toString().trim();

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: MqRadius.brMd,
                ),
                child: Icon(icon, color: color, size: MqSize.iconSm),
              ),
              MqSpacing.gapMd,
              Expanded(
                child: Text(
                  sessionTitle.isNotEmpty ? sessionTitle : 'جلسة',
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              MqBadge(label: label, tone: tone),
            ],
          ),
          MqSpacing.gapSm,
          Row(
            children: [
              if (occurred.isNotEmpty) ...[
                Icon(Icons.event_outlined, size: 13, color: m.ink3),
                MqSpacing.gapXxs,
                Text(occurred, style: context.text.labelSmall),
                MqSpacing.gapMd,
              ],
              if (checkin.isNotEmpty) ...[
                Icon(Icons.schedule_rounded, size: 13, color: m.ink3),
                MqSpacing.gapXxs,
                Text(checkin, style: context.text.labelSmall),
              ],
            ],
          ),
          if (notes.isNotEmpty) ...[
            MqSpacing.gapSm,
            MqSurface(
              tone: MqSurfaceTone.neutral,
              padding: const EdgeInsets.symmetric(
                horizontal: MqSpacing.sm,
                vertical: MqSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: 13, color: m.ink3),
                  MqSpacing.gapXs,
                  Expanded(
                    child: Text(
                      notes,
                      style: context.text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── states ──────────────────────────────────────────────────────────────────

  Widget _empty(BuildContext context, String title, String body) {
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
                decoration: BoxDecoration(
                  color: m.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_available_outlined,
                  size: 44,
                  color: m.accent,
                ),
              ),
              MqSpacing.gapMd,
              Text(title, style: context.text.titleMedium),
              MqSpacing.gapXs,
              Text(
                body,
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
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
              Text(
                _error ?? 'حدث خطأ',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium,
              ),
              MqSpacing.gapMd,
              MqButton(
                label: 'إعادة المحاولة',
                icon: Icons.refresh_rounded,
                expand: false,
                onPressed: _fetch,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    Widget block(double h) => Container(
      height: h,
      decoration: BoxDecoration(color: m.fill2, borderRadius: MqRadius.brLg),
    );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        MqSpacing.lg,
        MqSpacing.lg,
        MqSpacing.lg,
        MqSpacing.lg,
      ),
      children: [
        Row(
          children: [
            Expanded(child: block(72)),
            MqSpacing.gapSm,
            Expanded(child: block(72)),
            MqSpacing.gapSm,
            Expanded(child: block(72)),
          ],
        ),
        MqSpacing.gapLg,
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.sm),
            child: MqCard(
              padding: const EdgeInsets.all(MqSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: m.fill2,
                      borderRadius: MqRadius.brMd,
                    ),
                  ),
                  MqSpacing.gapMd,
                  Expanded(
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: m.fill2,
                        borderRadius: MqRadius.brSm,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _fmtDay(dynamic v) {
    final iso = v?.toString();
    if (iso == null || iso.isEmpty) return '';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }

  String _fmtTime(dynamic v) {
    final iso = v?.toString();
    if (iso == null || iso.isEmpty) return '';
    try {
      return formatTime12(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }
}
