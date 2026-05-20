import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_bottom_nav.dart';
import '../shared/teacher_helpers.dart';

/// Teacher → "فواتير الطلاب" (manage-invoices.vue).
class TeacherInvoicesScreen extends StatefulWidget {
  const TeacherInvoicesScreen({super.key});
  @override
  State<TeacherInvoicesScreen> createState() => _TeacherInvoicesScreenState();
}

class _TeacherInvoicesScreenState extends State<TeacherInvoicesScreen> {
  final _api = TeacherApiService();

  List<String> _years = [];
  String? _studyYear;
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _summary = const {};
  String? _statusFilter;
  String _search = '';
  final _searchCtl = TextEditingController();

  static const _statuses = [
    {'value': null, 'label': 'الكل', 'color': Color(0xFF0B2545)},
    {'value': 'paid', 'label': 'مدفوعة', 'color': Colors.green},
    {'value': 'partial', 'label': 'جزئية', 'color': kSky},
    {'value': 'pending', 'label': 'معلّقة', 'color': kOrange},
    {'value': 'overdue', 'label': 'متأخرة', 'color': Colors.red},
  ];

  @override
  void initState() { super.initState(); _bootstrap(); }
  @override
  void dispose() { _searchCtl.dispose(); super.dispose(); }

  Future<void> _bootstrap() async {
    try {
      final res = await _api.fetchAcademicYears();
      final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
      final years = (data['years'] is List) ? (data['years'] as List) : [];
      _years = years.map((y) => (y is Map ? (y['year']?.toString() ?? '') : y.toString())).where((s) => s.isNotEmpty).cast<String>().toList();
      _studyYear = (data['active'] is Map) ? data['active']['year']?.toString() : (_years.isNotEmpty ? _years.first : null);
      if (mounted) setState(() {});
    } catch (_) {}
    await _fetch();
  }

  Future<void> _fetch() async {
    if (_studyYear == null) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.fetchInvoices(studyYear: _studyYear!, status: _statusFilter, search: _search.trim().isEmpty ? null : _search.trim(), page: 1, limit: 100),
        _api.fetchInvoicesSummary(studyYear: _studyYear!, status: _statusFilter),
      ]);
      final list = results[0]['data'];
      _items = (list is List)
          ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : [];
      final s = results[1]['data'];
      _summary = s is Map ? Map<String, dynamic>.from(s) : const {};
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب الفواتير', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addPayment(Map<String, dynamic> inv) async {
    final remaining = num.tryParse((inv['remaining_amount'] ?? 0).toString()) ?? 0;
    final amountCtl = TextEditingController(text: remaining.toString());
    String method = 'cash';
    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
        title: const Text('إضافة دفعة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('المتبقّي: ${fmtIQD(remaining)}', style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 12),
          TextField(controller: amountCtl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: method,
            decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('نقد')),
              DropdownMenuItem(value: 'bank_transfer', child: Text('تحويل بنكي')),
              DropdownMenuItem(value: 'credit_card', child: Text('بطاقة')),
              DropdownMenuItem(value: 'mobile_payment', child: Text('دفع جوال')),
            ],
            onChanged: (v) => setLocal(() => method = v ?? 'cash'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تسديد')),
        ],
      ));
    });
    if (ok != true) return;
    final amount = num.tryParse(amountCtl.text.trim()) ?? 0;
    if (amount <= 0) return;
    try {
      await _api.addInvoicePayment(inv['id'].toString(), {'amount': amount, 'paymentMethod': method});
      Get.snackbar('تم', 'تمت إضافة الدفعة', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (e) {
      Get.snackbar('خطأ', 'تعذّر إضافة الدفعة', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _setDiscount(Map<String, dynamic> inv) async {
    final current = num.tryParse((inv['discount_total'] ?? 0).toString()) ?? 0;
    final ctl = TextEditingController(text: current.toString());
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('ضبط الخصم'),
      content: TextField(controller: ctl, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'قيمة الخصم', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.setInvoiceDiscount(inv['id'].toString(), num.tryParse(ctl.text.trim()) ?? 0);
      Get.snackbar('تم', 'تم ضبط الخصم', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (e) {
      Get.snackbar('خطأ', 'تعذّر ضبط الخصم', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _delete(Map<String, dynamic> inv) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: const Text('سيتم حذف الفاتورة. يمكن استرجاعها لاحقاً.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ));
    if (ok != true) return;
    try {
      await _api.deleteInvoice(inv['id'].toString());
      Get.snackbar('تم', 'تم الحذف', snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (e) {
      Get.snackbar('خطأ', 'تعذّر الحذف', snackPosition: SnackPosition.BOTTOM);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.trim().isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items.where((it) {
      final s = (it['student_name'] ?? '').toString().toLowerCase();
      final c = (it['course_name'] ?? '').toString().toLowerCase();
      return s.contains(q) || c.contains(q);
    }).toList();
  }

  Color _statusColor(String? s) {
    return _statuses.firstWhere((x) => x['value'] == s, orElse: () => _statuses[0])['color'] as Color;
  }

  String _statusLabel(String? s) {
    return _statuses.firstWhere((x) => x['value'] == s, orElse: () => _statuses[0])['label'] as String;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('فواتير الطلاب'),
        actions: [IconButton(onPressed: _loading ? null : _fetch, icon: const Icon(Icons.refresh))],
      ),
      drawer: const TeacherDrawer(),
      bottomNavigationBar: const TeacherBottomNav(),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TeacherHero(
              title: 'فواتير الطلاب',
              subtitle: 'السنة: ${_studyYear ?? '—'}',
              icon: Icons.receipt_long_outlined,
              trailing: _years.length > 1 ? PopupMenuButton<String>(
                initialValue: _studyYear,
                onSelected: (v) async { setState(() => _studyYear = v); await _fetch(); },
                itemBuilder: (ctx) => _years.map((y) => PopupMenuItem(value: y, child: Text(y))).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.expand_more, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('السنة', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ]),
                ),
              ) : null,
            ),
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12, mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                KpiTile(title: 'إجمالي الفواتير', value: fmtIQDShort(_summary['totalAmount']),
                    subtitle: '${fmtNum(_summary['totalCount'])} فاتورة',
                    icon: Icons.receipt_long_outlined, color: kNavy),
                KpiTile(title: 'المدفوع', value: fmtIQDShort(_summary['totalPaid']),
                    subtitle: '${fmtNum(_summary['paidCount'])} مدفوعة',
                    icon: Icons.check_circle_outline, color: Colors.green),
                KpiTile(title: 'المتبقّي', value: fmtIQDShort(_summary['totalRemaining']),
                    subtitle: '${fmtNum(_summary['pendingCount'])} معلّقة',
                    icon: Icons.hourglass_top_outlined, color: kOrange),
                KpiTile(title: 'الخصومات', value: fmtIQDShort(_summary['totalDiscount']),
                    subtitle: '${fmtNum(_summary['discountCount'])} مع خصم',
                    icon: Icons.percent_outlined, color: Colors.purple),
              ],
            ),
            const SizedBox(height: 16),

            // Status pills
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final s in _statuses) Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: StatusChip(
                    label: s['label'] as String,
                    selected: _statusFilter == s['value'],
                    onTap: () { setState(() => _statusFilter = s['value'] as String?); _fetch(); },
                    color: s['color'] as Color,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'بحث عن طالب أو كورس...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty ? null : IconButton(
                  onPressed: () { _searchCtl.clear(); setState(() => _search = ''); _fetch(); },
                  icon: const Icon(Icons.clear),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              onSubmitted: (_) => _fetch(),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_filtered.isEmpty)
              const EmptyState(message: 'لا توجد فواتير بهذه الفلاتر')
            else ..._filtered.map((inv) => _InvoiceTile(
                  inv: inv,
                  statusColor: _statusColor(inv['invoice_status'] as String?),
                  statusLabel: _statusLabel(inv['invoice_status'] as String?),
                  onAddPayment: () => _addPayment(inv),
                  onSetDiscount: () => _setDiscount(inv),
                  onDelete: () => _delete(inv),
                )),

            const SizedBox(height: 8),
            Text(' فتح الداشبورد لإنشاء فاتورة جديدة بطريقة متقدمة', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.inv, required this.statusColor, required this.statusLabel,
      required this.onAddPayment, required this.onSetDiscount, required this.onDelete});
  final Map<String, dynamic> inv;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onAddPayment, onSetDiscount, onDelete;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final amountDue = inv['amount_due'];
    final paid = inv['amount_paid'];
    final remaining = inv['remaining_amount'];
    final isPaid = (inv['invoice_status'] ?? '') == 'paid';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: statusColor.withValues(alpha: 0.18),
              child: Text(initialsOf(inv['student_name']?.toString()), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((inv['student_name'] ?? '—').toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text((inv['course_name'] ?? '—').toString(),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _AmountCell(label: 'المستحق', value: fmtIQDShort(amountDue), color: cs.onSurface),
          _AmountCell(label: 'المدفوع', value: fmtIQDShort(paid), color: Colors.green),
          _AmountCell(label: 'المتبقّي', value: fmtIQDShort(remaining), color: Colors.red),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          if (!isPaid) Expanded(child: OutlinedButton.icon(
            onPressed: onAddPayment,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('دفعة', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
          )),
          if (!isPaid) const SizedBox(width: 6),
          Expanded(child: OutlinedButton.icon(
            onPressed: onSetDiscount,
            icon: const Icon(Icons.percent, size: 16),
            label: const Text('خصم', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
          )),
          const SizedBox(width: 6),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
        ]),
      ]),
    );
  }
}

class _AmountCell extends StatelessWidget {
  const _AmountCell({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
    ]));
  }
}
