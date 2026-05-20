import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_helpers.dart';

/// Teacher → session attendance (attendance/[id].vue).
class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key, required this.sessionId, this.session});
  final String sessionId;
  final Map<String, dynamic>? session;
  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  final _api = TeacherApiService();
  bool _loading = false;
  bool _saving = false;
  List<Map<String, dynamic>> _students = [];
  Map<String, String?> _status = {};
  Map<String, String?> _original = {};
  DateTime _date = DateTime.now();
  String _search = '';
  final _searchCtl = TextEditingController();

  static const _statuses = [
    {'value': 'present', 'label': 'حاضر', 'color': Colors.green, 'icon': Icons.check},
    {'value': 'absent', 'label': 'غائب', 'color': Colors.red, 'icon': Icons.close},
    {'value': 'leave', 'label': 'إجازة', 'color': kOrange, 'icon': Icons.access_time},
  ];

  @override
  void initState() { super.initState(); _bootstrap(); }
  @override
  void dispose() { _searchCtl.dispose(); super.dispose(); }

  String get _dateISO => '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final atts = await _api.fetchSessionAttendees(widget.sessionId);
      final list = (atts['data'] is List) ? (atts['data'] as List) : [];
      _students = list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      await _loadDate();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDate() async {
    try {
      final res = await _api.fetchSessionAttendanceByDate(widget.sessionId, _dateISO);
      final data = (res['data'] is List) ? (res['data'] as List) : [];
      final map = <String, String?>{};
      for (final it in data) {
        if (it is Map) {
          final sid = (it['student_id'] ?? it['studentId'])?.toString();
          if (sid != null) map[sid] = it['status']?.toString();
        }
      }
      final merged = <String, String?>{};
      for (final s in _students) {
        final id = s['student_id'].toString();
        merged[id] = map[id];
      }
      setState(() {
        _status = merged;
        _original = Map.of(merged);
      });
    } catch (_) {}
  }

  bool get _dirty {
    for (final k in _status.keys) {
      if ((_status[k] ?? '') != (_original[k] ?? '')) return true;
    }
    return false;
  }

  Map<String, int> get _counts {
    int p = 0, a = 0, l = 0, u = 0;
    for (final s in _students) {
      switch (_status[s['student_id'].toString()]) {
        case 'present': p++; break;
        case 'absent': a++; break;
        case 'leave': l++; break;
        default: u++;
      }
    }
    return {'p': p, 'a': a, 'l': l, 'u': u};
  }

  void _setAll(String? value) {
    setState(() {
      for (final s in _students) {
        _status[s['student_id'].toString()] = value;
      }
    });
  }

  void _setOne(String studentId, String value) {
    setState(() {
      _status[studentId] = _status[studentId] == value ? null : value;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final items = _students.map((s) => {
        'studentId': s['student_id'].toString(),
        'status': _status[s['student_id'].toString()],
      }).toList();
      await _api.bulkSetSessionAttendance(widget.sessionId, _dateISO, items);
      Get.snackbar('تم', 'تم حفظ الحضور', snackPosition: SnackPosition.BOTTOM);
      setState(() => _original = Map.of(_status));
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر الحفظ', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 7)), locale: const Locale('ar'));
    if (d != null) { setState(() => _date = d); await _loadDate(); }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.trim().isEmpty) return _students;
    final q = _search.toLowerCase();
    return _students.where((s) => (s['student_name'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final counts = _counts;
    final pct = _students.isEmpty ? 0.0 : counts['p']! / _students.length;
    final isToday = _date.year == DateTime.now().year && _date.month == DateTime.now().month && _date.day == DateTime.now().day;
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الحضور')),
      bottomNavigationBar: SafeArea(child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          if (_dirty) Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: kOrange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 14, color: kOrange),
              SizedBox(width: 4), Text('تعديلات غير محفوظة', style: TextStyle(color: kOrange, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: (_saving || !_dirty) ? null : _save,
            icon: _saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
            label: const Text('حفظ الحضور'),
          ),
        ]),
      )),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.all(16), children: [
            // Session hero
            TeacherHero(
              title: (widget.session?['title'] ?? widget.session?['course_name'] ?? 'جلسة').toString(),
              subtitle: '${widget.session?['course_name'] ?? ''}',
              icon: Icons.calendar_today_outlined,
              trailing: InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_month, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(isToday ? 'اليوم' : _dateISO, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stats
            Row(children: [
              _StatChip(label: 'حاضر', value: counts['p']!, color: Colors.green),
              _StatChip(label: 'غائب', value: counts['a']!, color: Colors.red),
              _StatChip(label: 'إجازة', value: counts['l']!, color: kOrange),
              _StatChip(label: 'لم يُحدّد', value: counts['u']!, color: Colors.grey),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: pct, color: Colors.green, backgroundColor: Colors.grey[200], minHeight: 6)),
            const SizedBox(height: 4),
            Text('نسبة الحضور: ${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),

            // Bulk actions
            Wrap(spacing: 8, runSpacing: 6, children: [
              const Text('سريع:', style: TextStyle(fontWeight: FontWeight.bold)),
              OutlinedButton.icon(onPressed: () => _setAll('present'), icon: const Icon(Icons.check, size: 14, color: Colors.green),
                  label: const Text('الكل حاضر', style: TextStyle(fontSize: 12)), style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact)),
              OutlinedButton.icon(onPressed: () => _setAll('absent'), icon: const Icon(Icons.close, size: 14, color: Colors.red),
                  label: const Text('الكل غائب', style: TextStyle(fontSize: 12)), style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact)),
              TextButton.icon(onPressed: () => _setAll(null), icon: const Icon(Icons.clear, size: 14),
                  label: const Text('مسح', style: TextStyle(fontSize: 12))),
            ]),
            const SizedBox(height: 12),

            // Search
            TextField(controller: _searchCtl, onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(hintText: 'بحث عن طالب...', prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true)),
            const SizedBox(height: 16),

            if (_students.isEmpty)
              const EmptyState(message: 'لا يوجد طلاب في هذه الجلسة بعد. أضفهم من لوحة التحكم.')
            else if (_filtered.isEmpty)
              EmptyState(message: 'لا يوجد طلاب باسم "$_search"')
            else ..._filtered.map((s) {
              final id = s['student_id'].toString();
              final cur = _status[id];
              final color = _statuses.firstWhere((x) => x['value'] == cur, orElse: () => {'color': Colors.grey})['color'] as Color;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.2))),
                child: Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: color,
                      child: Text(initialsOf((s['student_name'] ?? '?').toString()),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((s['student_name'] ?? '—').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (s['grade_name'] != null) Text(s['grade_name'].toString(), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ])),
                  Row(children: [
                    for (final st in _statuses) Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () => _setOne(id, st['value'] as String),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: cur == st['value'] ? (st['color'] as Color) : (st['color'] as Color).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(st['icon'] as IconData, size: 14,
                              color: cur == st['value'] ? Colors.white : st['color'] as Color),
                        ),
                      ),
                    ),
                  ]),
                ]),
              );
            }),
          ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(children: [
        Text(value.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ]),
    ));
  }
}
