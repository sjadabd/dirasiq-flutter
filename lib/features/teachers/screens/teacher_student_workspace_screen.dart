import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_service.dart';
import '../../../shared/widgets/status_views.dart';

/// Per-teacher workspace for the student.
///
/// Opens when the student taps a teacher on the new home. Calls a single
/// backend aggregate endpoint (`GET /student/teachers/:teacherId/aggregate`)
/// that returns teacher profile + shared courses + assignments + exams +
/// invoices + totals + urgency alerts in one round trip. No client-side
/// filtering — the backend already scopes everything to (studentId, teacherId).
class TeacherStudentWorkspaceScreen extends StatefulWidget {
  const TeacherStudentWorkspaceScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.courses,
  });
  final String teacherId;
  final String teacherName;

  /// Hint from the home (id + name + status). Used to render the hero
  /// optimistically while the aggregate call is in flight.
  final List<Map<String, dynamic>> courses;

  @override
  State<TeacherStudentWorkspaceScreen> createState() => _TeacherStudentWorkspaceScreenState();
}

class _TeacherStudentWorkspaceScreenState extends State<TeacherStudentWorkspaceScreen> {
  final _api = ApiService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _aggregate = const {};
  String _contentUrl = 'https://api.mulhimiq.com';

  Map<String, dynamic> get _teacher =>
      _aggregate['teacher'] is Map ? Map<String, dynamic>.from(_aggregate['teacher']) : <String, dynamic>{};
  Map<String, dynamic> get _counts =>
      _aggregate['counts'] is Map ? Map<String, dynamic>.from(_aggregate['counts']) : <String, dynamic>{};
  Map<String, dynamic> get _totals =>
      _aggregate['totals'] is Map ? Map<String, dynamic>.from(_aggregate['totals']) : <String, dynamic>{};
  List<Map<String, dynamic>> get _courses => _listFromAggregate('courses');
  List<Map<String, dynamic>> get _assignments => _listFromAggregate('assignments');
  List<Map<String, dynamic>> get _exams => _listFromAggregate('exams');
  List<Map<String, dynamic>> get _invoices => _listFromAggregate('invoices');
  List<Map<String, dynamic>> get _alerts => _listFromAggregate('alerts');

  List<Map<String, dynamic>> _listFromAggregate(String key) {
    final raw = _aggregate[key];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadContentUrl();
    _fetch();
  }

  Future<void> _loadContentUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _contentUrl = prefs.getString('content_url') ?? 'https://api.mulhimiq.com';
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchTeacherAggregate(widget.teacherId);
      if (!mounted) return;
      setState(() {
        _aggregate = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
        _loading = false;
      });
    }
  }

  String _cleanError(Object e) {
    final s = e.toString();
    if (s.contains('404')) return 'لم نعثر على هذا الأستاذ في قائمتك.';
    return 'تعذّر تحميل بيانات الأستاذ. تحقّق من الإنترنت وحاول مجدّداً.';
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first;
    return parts.first.characters.first + parts.last.characters.first;
  }

  String _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = _contentUrl.replaceAll(RegExp(r'/$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return '$base$p';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صفحة الأستاذ'),
        actions: [IconButton(onPressed: _loading ? null : _fetch, icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 120), StatusView.loading(message: 'جارٍ تحضير صفحة الأستاذ…')],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          StatusView.error(message: _error!, onAction: _fetch),
        ],
      );
    }
    return _buildLoaded();
  }

  Widget _buildLoaded() {
    final cs = Theme.of(context).colorScheme;
    final name = (_teacher['name'] ?? widget.teacherName).toString();
    final photo = _resolveImageUrl(_teacher['profileImagePath']?.toString());
    final coursesList = _courses.isNotEmpty
        ? _courses
        : widget.courses.map((c) => {'id': c['id'], 'name': c['name']}).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Hero(
          name: name,
          photoUrl: photo,
          initials: _initials(name),
          coursesCount: coursesList.length,
          city: _teacher['city']?.toString(),
        ),
        const SizedBox(height: 16),

        if (_alerts.isNotEmpty) ...[
          _AlertsCard(alerts: _alerts),
          const SizedBox(height: 16),
        ],

        // Course chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in coursesList)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.book_outlined, size: 14, color: Color(0xFF3FA9F5)),
                  const SizedBox(width: 6),
                  Text((c['name'] ?? '—').toString(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // KPIs
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.4,
          children: [
            _KpiTile(
              label: 'واجبات بانتظارك',
              value: '${_counts['assignmentsPending'] ?? 0}',
              icon: Icons.edit_note_outlined,
              color: const Color(0xFF3FA9F5),
            ),
            _KpiTile(
              label: 'امتحانات قادمة',
              value: '${_counts['examsUpcoming'] ?? 0}',
              icon: Icons.quiz_outlined,
              color: const Color(0xFF9333EA),
            ),
            _KpiTile(
              label: 'فواتير غير مدفوعة',
              value: '${_counts['invoicesUnpaid'] ?? 0}',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFFFF8A00),
            ),
            _KpiTile(
              label: 'متبقّي للدفع',
              value: _fmtNum(_totals['invoicesRemaining']),
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF10B981),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Sections
        _Section(
          title: 'الواجبات',
          icon: Icons.edit_note_outlined,
          color: const Color(0xFF3FA9F5),
          emptyHint: 'لا توجد واجبات حالياً',
          items: _assignments.take(5).map((a) => _ListItem(
            title: (a['title'] ?? '—').toString(),
            subtitle: 'موعد التسليم: ${_fmtDate(a['dueDate'])}',
            trailing: _statusChip((a['submissionStatus'] ?? 'pending').toString(), 'assignment'),
          )).toList(),
        ),
        _Section(
          title: 'الامتحانات',
          icon: Icons.quiz_outlined,
          color: const Color(0xFF9333EA),
          emptyHint: 'لا توجد امتحانات حالياً',
          items: _exams.take(5).map((e) => _ListItem(
            title: 'امتحان ${e['examType'] == 'monthly' ? 'شهري' : 'يومي'}',
            subtitle: 'تاريخ: ${_fmtDate(e['examDate'])}',
            trailing: _statusChip((e['examType'] ?? '').toString(), 'exam'),
          )).toList(),
        ),
        _Section(
          title: 'الفواتير',
          icon: Icons.receipt_long_outlined,
          color: const Color(0xFFFF8A00),
          emptyHint: 'لا توجد فواتير من هذا الأستاذ',
          items: _invoices.take(5).map((inv) => _ListItem(
            title: 'فاتورة بقيمة ${_fmtNum(inv['amountDue'])} د.ع',
            subtitle: 'المتبقّي: ${_fmtNum(inv['remainingAmount'])} د.ع',
            trailing: _statusChip((inv['invoiceStatus'] ?? '').toString(), 'invoice'),
          )).toList(),
        ),
      ],
    );
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    return '${d.day}/${d.month}/${d.year}';
  }

  String _fmtNum(dynamic v) {
    if (v == null) return '0';
    final n = (v is num) ? v : num.tryParse(v.toString());
    if (n == null) return '0';
    return n.toInt().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  Widget _statusChip(String s, String kind) {
    final m = {
      'pending': ['معلّق', Colors.orange],
      'submitted': ['مُسلَّم', Colors.green],
      'graded': ['مُصحَّح', Colors.blue],
      'late': ['متأخر', Colors.red],
      'returned': ['مُعاد', Colors.purple],
      'daily': ['يومي', Colors.blue],
      'monthly': ['شهري', Colors.purple],
      'paid': ['مدفوع', Colors.green],
      'partial': ['جزئي', Colors.blue],
      'overdue': ['متأخر', Colors.red],
    };
    final entry = m[s] ?? [s.isEmpty ? '—' : s, Colors.grey];
    final color = entry[1] as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(entry[0] as String, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.name,
    required this.photoUrl,
    required this.initials,
    required this.coursesCount,
    this.city,
  });
  final String name, photoUrl, initials;
  final int coursesCount;
  final String? city;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2545), Color(0xFF163E72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFFF8A00),
            shape: BoxShape.circle,
            image: photoUrl.isNotEmpty
                ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                : null,
          ),
          child: photoUrl.isEmpty
              ? Center(
                  child: Text(initials,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الأستاذ', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
            const SizedBox(height: 2),
            Text(name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.school_outlined, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text('$coursesCount كورس معك', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (city != null && city!.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(city!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.alerts});
  final List<Map<String, dynamic>> alerts;
  String _label(Map<String, dynamic> a) {
    final kind = (a['kind'] ?? '').toString();
    switch (kind) {
      case 'overdue_invoice':
        return 'فاتورة متأخّرة بقيمة ${a['amount']} د.ع';
      case 'assignment_due_soon':
        return 'واجب موعده يقترب';
      case 'upcoming_exam':
        return 'امتحان قريب';
      default:
        return 'تنبيه';
    }
  }

  IconData _icon(String kind) {
    switch (kind) {
      case 'overdue_invoice':
        return Icons.warning_amber_outlined;
      case 'assignment_due_soon':
        return Icons.assignment_late_outlined;
      case 'upcoming_exam':
        return Icons.event_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF8A00).withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.priority_high_rounded, color: Color(0xFFFF8A00), size: 18),
          SizedBox(width: 6),
          Text('تنبيهات تستحق الانتباه',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        for (final a in alerts.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(_icon((a['kind'] ?? '').toString()), size: 14, color: cs.onSurface),
              const SizedBox(width: 6),
              Expanded(child: Text(_label(a),
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ),
      ]),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value, required this.icon, required this.color});
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ])),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.emptyHint,
  });
  final String title, emptyHint;
  final IconData icon;
  final Color color;
  final List<_ListItem> items;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Text('${items.length}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text(emptyHint, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))))
          else
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(it.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ])),
                  const SizedBox(width: 8),
                  it.trailing,
                ]),
              ),
        ]),
      ),
    );
  }
}

class _ListItem {
  _ListItem({required this.title, required this.subtitle, required this.trailing});
  final String title, subtitle;
  final Widget trailing;
}
