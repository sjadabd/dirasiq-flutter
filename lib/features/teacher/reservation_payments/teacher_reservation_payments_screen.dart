import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_bottom_nav.dart';

/// Teacher → "فواتير عربون الطلاب".
///
/// Mirrors the dashboard's [show-reservation-payments.vue]:
///   • Hero with study-year selector
///   • 4 KPI cards (total / paid / remaining / discount)
///   • Filter chips: status (الكل / مدفوع / قيد الانتظار)
///   • Client-side search
///   • List of bookings with a "تسديد" button on pending rows
///   • Confirmation dialog before marking a deposit paid
///   • Pull-to-refresh
class TeacherReservationPaymentsScreen extends StatefulWidget {
  const TeacherReservationPaymentsScreen({super.key});

  @override
  State<TeacherReservationPaymentsScreen> createState() =>
      _TeacherReservationPaymentsScreenState();
}

class _TeacherReservationPaymentsScreenState
    extends State<TeacherReservationPaymentsScreen> {
  final TeacherApiService _api = TeacherApiService();

  // Reference data
  List<String> _years = [];
  String? _studyYear;
  String? _activeStudyYear;

  // Data
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _report = const {};

  // Filters
  String? _statusFilter; // null | 'paid' | 'pending'
  String _searchTerm = '';
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final res = await _api.fetchAcademicYears();
      final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
      final years = (data['years'] is List) ? (data['years'] as List) : [];
      _years = years
          .map((y) => (y is Map ? (y['year']?.toString() ?? '') : y.toString()))
          .where((s) => s.isNotEmpty)
          .toList()
          .cast<String>();
      _activeStudyYear = (data['active'] is Map) ? data['active']['year']?.toString() : null;
      _studyYear = _activeStudyYear ?? (_years.isNotEmpty ? _years.first : null);
      if (mounted) setState(() {});
    } catch (_) {
      // silent — fall back to manual selection
    }
    await _fetch();
  }

  Future<void> _fetch() async {
    if (_studyYear == null) return;
    setState(() => _loading = true);
    try {
      final res = await _api.fetchReservationPayments(
        studyYear: _studyYear!,
        page: 1,
        // Backend caps `limit` at 100 in paginationQuerySchema — sending more
        // returns 400 invalid_request. If we ever need more rows, paginate.
        limit: 100,
      );
      final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
      final items = (data['items'] is List) ? (data['items'] as List) : [];
      _items = items.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      _report = (data['report'] is Map) ? Map<String, dynamic>.from(data['report']) : const {};
    } catch (e) {
      // Surface the real reason so we don't get an opaque "تعذّر" on the
      // user's screen — usually it's a network reach issue or a 4xx body.
      Get.snackbar(
        'خطأ في جلب فواتير العربون',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 6),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmMarkPaid(Map<String, dynamic> item) async {
    final bookingId = (item['bookingId'] ?? item['id'])?.toString();
    if (bookingId == null || bookingId.isEmpty) return;
    final student = (item['studentName'] ?? '').toString();
    final amount = _fmt(item['amount']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تسديد العربون'),
        content: Text('سيتم تسجيل عربون $student بمبلغ $amount د.ع كمدفوع.\nلا يمكن التراجع بعد التسديد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.markReservationPaid(bookingId);
      Get.snackbar('تم', 'سُجّل العربون كمدفوع', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (e) {
      Get.snackbar('خطأ', 'تعذّر تسجيل العربون', snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ---------- Derived ----------

  List<Map<String, dynamic>> get _filteredItems {
    final q = _searchTerm.trim().toLowerCase();
    return _items.where((it) {
      if (_statusFilter != null && (it['status']?.toString() ?? '') != _statusFilter) return false;
      if (q.isEmpty) return true;
      final name = (it['studentName'] ?? '').toString().toLowerCase();
      final course = (it['courseName'] ?? '').toString().toLowerCase();
      return name.contains(q) || course.contains(q);
    }).toList();
  }

  // ---------- Helpers ----------

  String _fmt(dynamic n) {
    if (n == null) return '0';
    final v = (n is num) ? n : num.tryParse(n.toString());
    if (v == null) return '0';
    return v.toInt().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString().substring(0, v.toString().length.clamp(0, 10));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first;
    return parts.first.characters.first + parts.last.characters.first;
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totals = (_report['totals'] is Map) ? Map<String, dynamic>.from(_report['totals']) : const {};
    final counts = (_report['counts'] is Map) ? Map<String, dynamic>.from(_report['counts']) : const {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('فواتير عربون الطلاب'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: const TeacherDrawer(),
      bottomNavigationBar: const TeacherBottomNav(),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Hero with study-year selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B2545), Color(0xFF163E72)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22, backgroundColor: Color(0xFFFF8A00),
                    child: Icon(Icons.local_atm_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('فواتير العربون',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('السنة: ${_studyYear ?? '—'}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                      ],
                    ),
                  ),
                  if (_years.length > 1)
                    PopupMenuButton<String>(
                      initialValue: _studyYear,
                      onSelected: (v) async { setState(() => _studyYear = v); await _fetch(); },
                      itemBuilder: (ctx) => _years.map((y) => PopupMenuItem(value: y, child: Text(y))).toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.expand_more, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('السنة', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4 KPI cards (2x2)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12, mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _Kpi(title: 'إجمالي العربون',  value: _fmt(totals['totalAmount']),     subtitle: 'المتوقع',
                    icon: Icons.account_balance_outlined, color: cs.primary),
                _Kpi(title: 'المُستلَم',         value: _fmt(totals['totalPaidAmount']), subtitle: '${_fmt(counts['totalPaid'])} مدفوع',
                    icon: Icons.check_circle_outline,    color: Colors.green),
                _Kpi(title: 'المتبقّي',          value: _fmt(totals['remainingAmount']),  subtitle: '${_fmt(counts['totalPending'])} معلّق',
                    icon: Icons.hourglass_top_outlined,  color: const Color(0xFFFF8A00)),
                _Kpi(title: 'الخصومات',          value: _fmt(totals['discountAmount']),   subtitle: 'مجموع',
                    icon: Icons.percent_outlined,         color: Colors.purple),
              ],
            ),

            const SizedBox(height: 16),

            // Filter + search
            Row(
              children: [
                _StatusChip(label: 'الكل',       selected: _statusFilter == null,       onTap: () => setState(() => _statusFilter = null),       color: cs.primary),
                const SizedBox(width: 8),
                _StatusChip(label: 'مدفوع',      selected: _statusFilter == 'paid',    onTap: () => setState(() => _statusFilter = 'paid'),    color: Colors.green),
                const SizedBox(width: 8),
                _StatusChip(label: 'معلّق',      selected: _statusFilter == 'pending', onTap: () => setState(() => _statusFilter = 'pending'), color: const Color(0xFFFF8A00)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _searchTerm = v),
              decoration: InputDecoration(
                hintText: 'بحث عن طالب أو كورس...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchTerm.isEmpty
                    ? null
                    : IconButton(onPressed: () { _searchCtl.clear(); setState(() => _searchTerm = ''); }, icon: const Icon(Icons.clear)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),

            const SizedBox(height: 16),

            // List
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_filteredItems.isEmpty)
              _EmptyState(hasFilter: _statusFilter != null || _searchTerm.isNotEmpty)
            else
              ..._filteredItems.map((it) => _PaymentTile(
                    item: it,
                    fmt: _fmt,
                    fmtDate: _fmtDate,
                    initials: _initials,
                    onMarkPaid: () => _confirmMarkPaid(it),
                  )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Kpi extends StatelessWidget {
  const _Kpi({required this.title, required this.value, required this.subtitle, required this.icon, required this.color});
  final String title, value, subtitle;
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart,
                child: Text(value, maxLines: 1, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
              ),
              const SizedBox(height: 2),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.selected, required this.onTap, required this.color});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.w600, fontSize: 12)),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.item,
    required this.fmt, required this.fmtDate, required this.initials,
    required this.onMarkPaid,
  });
  final Map<String, dynamic> item;
  final String Function(dynamic) fmt;
  final String Function(dynamic) fmtDate;
  final String Function(String) initials;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = (item['status'] ?? '').toString();
    final isPaid = status == 'paid';
    final color = isPaid ? Colors.green : const Color(0xFFFF8A00);
    final studentName = (item['studentName'] ?? '—').toString();
    final courseName = (item['courseName'] ?? '—').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.18),
                child: Text(initials(studentName),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(courseName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(isPaid ? 'مدفوع' : 'معلّق',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MetaCell(icon: Icons.attach_money, label: 'المبلغ', value: '${fmt(item['amount'])} د.ع'),
              _MetaCell(icon: Icons.event, label: 'تاريخ الدفع', value: fmtDate(item['paidAt'])),
            ],
          ),
          if (!isPaid) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onMarkPaid,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('تسديد العربون'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF8A00)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            hasFilter ? 'لا توجد نتائج بهذه الفلاتر' : 'لا توجد فواتير عربون في هذه السنة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
