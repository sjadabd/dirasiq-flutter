import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/core/services/api_service.dart';

class CourseAttendanceScreen extends StatefulWidget {
  final String courseId;
  final String? courseName;

  const CourseAttendanceScreen({super.key, required this.courseId, this.courseName});

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
      // expected: { items: [...] } or a map with lists
      final dynamic rawItems = res['items'] ?? res['records'] ?? res['attendance'] ?? res['data'] ?? res;
      final list = (rawItems is List) ? rawItems : [];
      setState(() {
        _items = List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.courseName ?? 'سجل الحضور';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlobalAppBar(title: title, centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: _fetch,
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    final counts = _computeCounts(_items);
    final filtered = _filteredItems();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _summaryRow(counts),
        const SizedBox(height: 12),
        _filterChips(counts),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  _filter == 'all' ? 'لا توجد سجلات حالياً' : 'لا توجد سجلات لهذه الحالة',
                ),
              ),
            ),
          )
        else
          ...filtered.map(_attendanceTile),
      ],
    );
  }

  Map<String, int> _computeCounts(List<Map<String, dynamic>> list) {
    int present = 0, absent = 0, leave = 0;
    for (final r in list) {
      final s = (r['status'] ?? r['attendanceStatus'] ?? r['type'] ?? '').toString().toLowerCase();
      if (s.contains('present') || s == 'حضور' || s == 'presented') present++;
      else if (s.contains('absent') || s == 'غياب') absent++;
      else if (s.contains('leave') || s == 'اجازة' || s == 'إجازة') leave++;
    }
    return {
      'total': list.length,
      'present': present,
      'absent': absent,
      'leave': leave,
    };
  }

  List<Map<String, dynamic>> _filteredItems() {
    if (_filter == 'all') return _sorted(_items);
    return _sorted(_items.where((r) {
      final s = (r['status'] ?? r['attendanceStatus'] ?? r['type'] ?? '').toString().toLowerCase();
      if (_filter == 'present') return s.contains('present') || s == 'حضور' || s == 'presented';
      if (_filter == 'absent') return s.contains('absent') || s == 'غياب';
      if (_filter == 'leave') return s.contains('leave') || s == 'اجازة' || s == 'إجازة';
      return true;
    }).toList());
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> list) {
    final copy = [...list];
    copy.sort((a, b) {
      final ad = _parseDate(
        a['checkin_at'] ?? a['occurred_on'] ?? a['date'] ?? a['sessionDate'] ?? a['createdAt'],
      );
      final bd = _parseDate(
        b['checkin_at'] ?? b['occurred_on'] ?? b['date'] ?? b['sessionDate'] ?? b['createdAt'],
      );
      return bd.compareTo(ad); // latest first
    });
    return copy;
  }

  DateTime _parseDate(dynamic v) {
    try {
      if (v == null) return DateTime.fromMicrosecondsSinceEpoch(0);
      final s = v.toString();
      // Support date-only like 2025-09-30
      if (s.length <= 10 && s.contains('-')) {
        return DateTime.parse(s);
      }
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.fromMicrosecondsSinceEpoch(0);
    }
  }

  Widget _summaryRow(Map<String, int> c) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _summaryCard(icon: Icons.check_circle, label: 'حضور', value: c['present'] ?? 0, color: Colors.green, scheme: scheme),
        const SizedBox(width: 8),
        _summaryCard(icon: Icons.cancel, label: 'غياب', value: c['absent'] ?? 0, color: Colors.red, scheme: scheme),
        const SizedBox(width: 8),
        _summaryCard(icon: Icons.event_busy, label: 'إجازة', value: c['leave'] ?? 0, color: Colors.orange, scheme: scheme),
      ],
    );
  }

  Expanded _summaryCard({required IconData icon, required String label, required int value, required Color color, required ColorScheme scheme}) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(.12),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.outline),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChips(Map<String, int> c) {
    final scheme = Theme.of(context).colorScheme;
    Chip _chip(String key, String label, {IconData? icon}) {
      final selected = _filter == key;
      return Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 6),
            ],
            Text(label),
          ],
        ),
        backgroundColor: selected ? scheme.primary.withOpacity(.12) : scheme.surface,
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        GestureDetector(onTap: () => setState(() => _filter = 'all'), child: _chip('all', 'الكل', icon: Icons.list_alt)),
        GestureDetector(onTap: () => setState(() => _filter = 'present'), child: _chip('present', 'الحضور', icon: Icons.check_circle)),
        GestureDetector(onTap: () => setState(() => _filter = 'absent'), child: _chip('absent', 'الغياب', icon: Icons.cancel)),
        GestureDetector(onTap: () => setState(() => _filter = 'leave'), child: _chip('leave', 'الإجازات', icon: Icons.event_busy)),
      ],
    );
  }

  Widget _attendanceTile(Map<String, dynamic> r) {
    final scheme = Theme.of(context).colorScheme;
    final statusRaw = (r['status'] ?? r['attendanceStatus'] ?? r['type'] ?? '').toString().toLowerCase();
    String title;
    IconData icon;
    Color color;
    if (statusRaw.contains('present') || statusRaw == 'حضور' || statusRaw == 'presented') {
      title = 'حضور';
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (statusRaw.contains('absent') || statusRaw == 'غياب') {
      title = 'غياب';
      icon = Icons.cancel;
      color = Colors.red;
    } else if (statusRaw.contains('leave') || statusRaw == 'اجازة' || statusRaw == 'إجازة') {
      title = 'إجازة';
      icon = Icons.event_busy;
      color = Colors.orange;
    } else {
      title = statusRaw.isEmpty ? 'غير محدد' : statusRaw;
      icon = Icons.help_outline;
      color = scheme.primary;
    }

    final occurredRaw = r['occurred_on'] ?? r['date'] ?? r['sessionDate'] ?? r['createdAt'];
    final checkinRaw = r['checkin_at'];
    final checkin12hRaw = r['checkin_at_12h'];
    final occurred = _safeFormatDateDay(occurredRaw?.toString());
    final checkin = (checkin12hRaw != null && checkin12hRaw.toString().isNotEmpty)
        ? checkin12hRaw.toString()
        : _safeFormatDateTime(checkinRaw?.toString());
    final sessionTitle = (r['sessionTitle'] ?? r['title'] ?? r['session']?['title'] ?? '').toString();
    final notes = (r['notes'] ?? r['reason'] ?? '').toString();

    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color)),
        title: Text(sessionTitle.isNotEmpty ? sessionTitle : title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sessionTitle.isNotEmpty) Text(title),
            if (occurred.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('تاريخ الجلسة: $occurred', style: TextStyle(color: scheme.outline)),
            ],
            if (checkin.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('وقت التسجيل: $checkin', style: TextStyle(color: scheme.outline)),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(notes),
            ],
          ],
        ),
      ),
    );
  }

  String _safeFormatDateDay(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      // accept date-only
      if (iso.length <= 10) {
        final d = DateTime.parse(iso).toLocal();
        return DateFormat('dd/MM/yyyy').format(d);
      }
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return '';
    }
  }

  String _safeFormatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('HH:mm').format(d);
    } catch (_) {
      return '';
    }
  }
}
