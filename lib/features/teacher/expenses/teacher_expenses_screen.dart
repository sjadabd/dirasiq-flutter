import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_bottom_nav.dart';
import '../shared/teacher_helpers.dart';

/// Teacher → "المصاريف" (manage-expenses.vue) — full CRUD.
class TeacherExpensesScreen extends StatefulWidget {
  const TeacherExpensesScreen({super.key});
  @override
  State<TeacherExpensesScreen> createState() => _TeacherExpensesScreenState();
}

class _TeacherExpensesScreenState extends State<TeacherExpensesScreen> {
  final _api = TeacherApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _summary = const {};
  String? _category;
  String _search = '';
  final _searchCtl = TextEditingController();

  static const _categories = [
    {'value': 'salaries', 'label': 'رواتب'},
    {'value': 'rent', 'label': 'إيجار'},
    {'value': 'utilities', 'label': 'كهرباء وماء'},
    {'value': 'maintenance', 'label': 'صيانة'},
    {'value': 'stationery', 'label': 'قرطاسية'},
    {'value': 'other', 'label': 'أخرى'},
  ];

  static const _methods = [
    {'value': 'cash', 'label': 'نقد'},
    {'value': 'bank_transfer', 'label': 'تحويل بنكي'},
    {'value': 'card', 'label': 'بطاقة'},
  ];

  @override
  void initState() { super.initState(); _fetch(); }
  @override
  void dispose() { _searchCtl.dispose(); super.dispose(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchExpenses(category: _category, search: _search.trim().isEmpty ? null : _search.trim(), page: 1, limit: 100);
      final list = res['data'];
      _items = (list is List) ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : [];
      final meta = (res['meta'] is Map) ? Map<String, dynamic>.from(res['meta']) : {};
      _summary = (meta['summary'] is Map) ? Map<String, dynamic>.from(meta['summary']) : {};
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب المصاريف', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editDialog({Map<String, dynamic>? existing}) async {
    final amount = TextEditingController(text: (existing?['amount'] ?? '').toString());
    final note = TextEditingController(text: (existing?['note'] ?? '').toString());
    String cat = (existing?['category'] ?? 'other').toString();
    String method = (existing?['payment_method'] ?? 'cash').toString();
    DateTime date = DateTime.tryParse((existing?['expense_date'] ?? '').toString()) ?? DateTime.now();

    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: Text(existing == null ? 'إضافة مصروف' : 'تعديل المصروف'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: amount, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'المبلغ *', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        InkWell(onTap: () async {
          final d = await showDatePicker(context: ctx, initialDate: date,
              firstDate: DateTime(2020), lastDate: DateTime(2030), locale: const Locale('ar'));
          if (d != null) setLocal(() => date = d);
        }, child: InputDecorator(
          decoration: const InputDecoration(labelText: 'تاريخ المصروف *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
          child: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
        )),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: cat,
          decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
          items: [for (final c in _categories) DropdownMenuItem(value: c['value'], child: Text(c['label']!))],
          onChanged: (v) => setLocal(() => cat = v ?? 'other'),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: method,
          decoration: const InputDecoration(labelText: 'طريقة الدفع', border: OutlineInputBorder()),
          items: [for (final m in _methods) DropdownMenuItem(value: m['value'], child: Text(m['label']!))],
          onChanged: (v) => setLocal(() => method = v ?? 'cash'),
        ),
        const SizedBox(height: 8),
        TextField(controller: note, maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظة', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
      ],
    )));
    if (ok != true) return;
    final amt = num.tryParse(amount.text.trim()) ?? 0;
    if (amt <= 0) { Get.snackbar('تنبيه', 'المبلغ يجب أن يكون أكبر من صفر', snackPosition: SnackPosition.BOTTOM); return; }
    try {
      final payload = <String, dynamic>{
        'amount': amt,
        'expense_date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'category': cat,
        'paymentMethod': method,
      };
      if (note.text.trim().isNotEmpty) payload['note'] = note.text.trim();
      if (existing == null) {
        await _api.createExpense(payload);
        Get.snackbar('تم', 'تمت الإضافة', snackPosition: SnackPosition.BOTTOM);
      } else {
        await _api.updateExpense(existing['id'].toString(), payload);
        Get.snackbar('تم', 'تم التعديل', snackPosition: SnackPosition.BOTTOM);
      }
      await _fetch();
    } catch (_) { Get.snackbar('خطأ', 'تعذّر الحفظ', snackPosition: SnackPosition.BOTTOM); }
  }

  Future<void> _delete(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد الحذف'), content: const Text('سيتم حذف المصروف. يمكن استرجاعه.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ));
    if (ok != true) return;
    try { await _api.deleteExpense(e['id'].toString()); await _fetch(); Get.snackbar('تم', 'تم الحذف', snackPosition: SnackPosition.BOTTOM); }
    catch (_) { Get.snackbar('خطأ', 'تعذّر الحذف', snackPosition: SnackPosition.BOTTOM); }
  }

  String _catLabel(String? c) => _categories.firstWhere((x) => x['value'] == c, orElse: () => {'label': '—'})['label']!;
  String _methodLabel(String? m) => _methods.firstWhere((x) => x['value'] == m, orElse: () => {'label': '—'})['label']!;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('المصاريف'), actions: [IconButton(onPressed: _loading ? null : _fetch, icon: const Icon(Icons.refresh))]),
      drawer: const TeacherDrawer(),
      bottomNavigationBar: const TeacherBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editDialog(), icon: const Icon(Icons.add), label: const Text('إضافة مصروف'),
        backgroundColor: kOrange, foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(onRefresh: _fetch, child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
        TeacherHero(title: 'المصاريف', subtitle: 'إجمالي: ${fmtIQDShort(_summary['totalAmount'])}', icon: Icons.shopping_cart_outlined),
        const SizedBox(height: 16),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4, children: [
          KpiTile(title: 'إجمالي المصاريف', value: fmtIQDShort(_summary['totalAmount']),
              subtitle: '${fmtNum(_summary['count'])} سجل', icon: Icons.payments_outlined, color: Colors.red),
          KpiTile(title: 'سجلات', value: fmtNum(_summary['count']),
              subtitle: 'هذه الفترة', icon: Icons.list_alt_outlined, color: kNavy),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
          Padding(padding: const EdgeInsets.only(left: 8), child: StatusChip(label: 'الكل', selected: _category == null,
              onTap: () { setState(() => _category = null); _fetch(); }, color: kNavy)),
          for (final c in _categories) Padding(padding: const EdgeInsets.only(left: 8),
            child: StatusChip(label: c['label']!, selected: _category == c['value'],
                onTap: () { setState(() => _category = c['value']); _fetch(); }, color: kSky)),
        ])),
        const SizedBox(height: 10),
        TextField(controller: _searchCtl, onChanged: (v) => setState(() => _search = v), onSubmitted: (_) => _fetch(),
            decoration: InputDecoration(hintText: 'بحث في الملاحظات...', prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true)),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (_items.isEmpty)
          const EmptyState(message: 'لا توجد مصاريف. أضف مصروفاً من زر +')
        else ..._items.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4))),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.shopping_cart_outlined, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmtIQD(e['amount']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15)),
                  Text('${_catLabel(e['category']?.toString())} · ${_methodLabel(e['payment_method']?.toString())}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  if ((e['note'] ?? '').toString().isNotEmpty)
                    Text(e['note'].toString(), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(fmtDate(e['expense_date']), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
                ])),
                IconButton(onPressed: () => _editDialog(existing: e), icon: const Icon(Icons.edit_outlined, size: 18), visualDensity: VisualDensity.compact),
                IconButton(onPressed: () => _delete(e), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), visualDensity: VisualDensity.compact),
              ]),
            )),
      ])),
    );
  }
}
