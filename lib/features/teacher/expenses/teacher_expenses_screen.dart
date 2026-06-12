import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_helpers.dart' show fmtNum, fmtIQD, fmtIQDShort, fmtDate;

/// Teacher → "المصاريف" — full CRUD (Teacher Design System pass).
///
/// Presentation only — `fetchExpenses`, `createExpense`, `updateExpense`,
/// `deleteExpense`, the category filter, and the search are UNCHANGED. Restyled
/// to the teacher design system: hero, KPI grid, MqChip category filters,
/// redesigned expense cards, accent FAB. The add/edit/delete dialogs are kept.
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
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchExpenses(
          category: _category,
          search: _search.trim().isEmpty ? null : _search.trim(),
          page: 1,
          limit: 100);
      final list = res['data'];
      _items = (list is List)
          ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : [];
      final meta = (res['meta'] is Map) ? Map<String, dynamic>.from(res['meta']) : {};
      _summary =
          (meta['summary'] is Map) ? Map<String, dynamic>.from(meta['summary']) : {};
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب المصاريف',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Animated add/edit modal. A design-system bottom sheet that slides up on
  /// show and down on dismiss (custom [transitionAnimationController] curve).
  /// `createExpense` / `updateExpense` and the validation are unchanged.
  Future<void> _showExpenseSheet({Map<String, dynamic>? existing}) async {
    final amountCtl =
        TextEditingController(text: (existing?['amount'] ?? '').toString());
    final noteCtl =
        TextEditingController(text: (existing?['note'] ?? '').toString());
    String cat = (existing?['category'] ?? 'other').toString();
    String method = (existing?['payment_method'] ?? 'cash').toString();
    DateTime date =
        DateTime.tryParse((existing?['expense_date'] ?? '').toString()) ??
            DateTime.now();
    bool saving = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Theme(
        data: isDark ? MqTheme.dark() : MqTheme.light(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(builder: (sheetCtx, setLocal) {
            final mq = sheetCtx.mq;

            Future<void> save() async {
              final amt = num.tryParse(amountCtl.text.trim()) ?? 0;
              if (amt <= 0) {
                Get.snackbar('تنبيه', 'المبلغ يجب أن يكون أكبر من صفر',
                    snackPosition: SnackPosition.BOTTOM);
                return;
              }
              setLocal(() => saving = true);
              try {
                final payload = <String, dynamic>{
                  'amount': amt,
                  'expense_date': _ymd(date),
                  'category': cat,
                  'paymentMethod': method,
                };
                if (noteCtl.text.trim().isNotEmpty) {
                  payload['note'] = noteCtl.text.trim();
                }
                if (existing == null) {
                  await _api.createExpense(payload);
                } else {
                  await _api.updateExpense(existing['id'].toString(), payload);
                }
                if (sheetCtx.mounted) Navigator.pop(sheetCtx, true);
              } catch (_) {
                setLocal(() => saving = false);
                Get.snackbar('خطأ', 'تعذّر الحفظ',
                    snackPosition: SnackPosition.BOTTOM);
              }
            }

            Widget label(String s) => Padding(
                  padding: const EdgeInsets.only(bottom: MqSpacing.sm),
                  child: Text(s,
                      style: sheetCtx.text.labelMedium
                          ?.copyWith(color: mq.ink2)),
                );

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
                              child: Icon(
                                  existing == null
                                      ? Icons.add_rounded
                                      : Icons.edit_outlined,
                                  size: MqSize.iconSm,
                                  color: mq.accent),
                            ),
                            const SizedBox(width: MqSpacing.sm),
                            Expanded(
                              child: Text(
                                  existing == null
                                      ? 'إضافة مصروف'
                                      : 'تعديل المصروف',
                                  style: sheetCtx.text.titleMedium),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(sheetCtx, false),
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded, color: mq.ink3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: MqSpacing.lg),
                        TextField(
                          controller: amountCtl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المبلغ *',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                        ),
                        const SizedBox(height: MqSpacing.md),
                        InkWell(
                          borderRadius: MqRadius.brMd,
                          onTap: () async {
                            final d = await showDatePicker(
                                context: sheetCtx,
                                initialDate: date,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                locale: const Locale('ar'));
                            if (d != null) setLocal(() => date = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'تاريخ المصروف',
                              prefixIcon: Icon(Icons.event_outlined),
                            ),
                            child: Text(_ymd(date),
                                style: sheetCtx.text.bodyMedium),
                          ),
                        ),
                        const SizedBox(height: MqSpacing.lg),
                        label('التصنيف'),
                        Wrap(
                          spacing: MqSpacing.sm,
                          runSpacing: MqSpacing.sm,
                          children: [
                            for (final c in _categories)
                              MqChip(
                                label: c['label']!,
                                selected: cat == c['value'],
                                onTap: () => setLocal(() => cat = c['value']!),
                              ),
                          ],
                        ),
                        const SizedBox(height: MqSpacing.lg),
                        label('طريقة الدفع'),
                        Wrap(
                          spacing: MqSpacing.sm,
                          runSpacing: MqSpacing.sm,
                          children: [
                            for (final m in _methods)
                              MqChip(
                                label: m['label']!,
                                selected: method == m['value'],
                                onTap: () =>
                                    setLocal(() => method = m['value']!),
                              ),
                          ],
                        ),
                        const SizedBox(height: MqSpacing.lg),
                        label('ملاحظة'),
                        TextField(
                          controller: noteCtl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'ملاحظة اختيارية...',
                          ),
                        ),
                        const SizedBox(height: MqSpacing.xl),
                        MqButton(
                          label: saving ? 'جارٍ الحفظ…' : 'حفظ',
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

    // Dispose after the sheet's slide-out animation; disposing while the
    // TextFields are still rebuilding crashes with "ChangeNotifier used after
    // dispose" (the red `_dependents.isEmpty` screen).
    Future.delayed(const Duration(milliseconds: 500), () {
      amountCtl.dispose();
      noteCtl.dispose();
    });

    if (ok == true) {
      Get.snackbar('تم', existing == null ? 'تمت الإضافة' : 'تم التعديل',
          snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    }
  }

  Future<void> _delete(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('تأكيد الحذف'),
              content: const Text('سيتم حذف المصروف. يمكن استرجاعه.'),
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
      await _api.deleteExpense(e['id'].toString());
      await _fetch();
      Get.snackbar('تم', 'تم الحذف', snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر الحذف', snackPosition: SnackPosition.BOTTOM);
    }
  }

  String _catLabel(String? c) =>
      _categories.firstWhere((x) => x['value'] == c, orElse: () => {'label': '—'})['label']!;
  String _methodLabel(String? m) =>
      _methods.firstWhere((x) => x['value'] == m, orElse: () => {'label': '—'})['label']!;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;
          return Scaffold(
            backgroundColor: mq.page,
            appBar: TeacherAppBar(
              title: 'المصاريف',
              actions: [_RefreshAction(loading: _loading, onTap: _fetch)],
            ),
            drawer: const TeacherDrawer(),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showExpenseSheet(),
              backgroundColor: mq.accent,
              foregroundColor: mq.onAccent,
              elevation: 3,
              tooltip: 'إضافة مصروف',
              shape: const RoundedRectangleBorder(borderRadius: MqRadius.brLg),
              child: const Icon(Icons.add_rounded),
            ),
            body: RefreshIndicator(
              onRefresh: _fetch,
              color: mq.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, 96),
                children: [
                  _hero(context),
                  const SizedBox(height: MqSpacing.lg),
                  _kpiGrid(context),
                  const SizedBox(height: MqSpacing.lg),
                  _filterRow(context),
                  const SizedBox(height: MqSpacing.md),
                  _searchField(context),
                  const SizedBox(height: MqSpacing.lg),
                  if (_loading && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(MqSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_items.isEmpty)
                    _EmptyState(
                        hasFilter:
                            _category != null || _search.trim().isNotEmpty)
                  else
                    ..._items.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: MqSpacing.md),
                          child: _ExpenseCard(
                            expense: e,
                            categoryLabel: _catLabel(e['category']?.toString()),
                            methodLabel:
                                _methodLabel(e['payment_method']?.toString()),
                            onEdit: () => _showExpenseSheet(existing: e),
                            onDelete: () => _delete(e),
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

  // ---- hero -----------------------------------------------------------------

  Widget _hero(BuildContext context) {
    final t = context.teacher;
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
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration:
                BoxDecoration(color: context.mq.orange, shape: BoxShape.circle),
            child: const Icon(Icons.shopping_cart_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المصاريف',
                    style: context.text.titleMedium?.copyWith(color: t.heroInk)),
                const SizedBox(height: 2),
                Text('إجمالي المصاريف: ${fmtIQD(_summary['totalAmount'])}',
                    style:
                        context.text.labelSmall?.copyWith(color: t.heroInk2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- KPIs -----------------------------------------------------------------

  Widget _kpiGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: MqSpacing.md,
      mainAxisSpacing: MqSpacing.md,
      childAspectRatio: 1.35,
      children: [
        TeacherKpiCard(
          label: 'إجمالي المصاريف',
          value: fmtIQDShort(_summary['totalAmount']),
          icon: Icons.payments_outlined,
          tone: TeacherTone.danger,
          caption: '${fmtNum(_summary['count'])} سجل',
        ),
        TeacherKpiCard(
          label: 'عدد السجلات',
          value: fmtNum(_summary['count']),
          icon: Icons.list_alt_outlined,
          tone: TeacherTone.info,
          caption: 'هذه الفترة',
        ),
      ],
    );
  }

  // ---- filters + search -----------------------------------------------------

  Widget _filterRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          MqChip(
            label: 'الكل',
            selected: _category == null,
            onTap: () {
              setState(() => _category = null);
              _fetch();
            },
          ),
          const SizedBox(width: MqSpacing.sm),
          for (final c in _categories) ...[
            MqChip(
              label: c['label']!,
              selected: _category == c['value'],
              onTap: () {
                setState(() => _category = c['value']);
                _fetch();
              },
            ),
            const SizedBox(width: MqSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    return TextField(
      controller: _searchCtl,
      onChanged: (v) => setState(() => _search = v),
      onSubmitted: (_) => _fetch(),
      decoration: InputDecoration(
        hintText: 'بحث في الملاحظات...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchCtl.clear();
                  setState(() => _search = '');
                  _fetch();
                },
                icon: const Icon(Icons.clear_rounded),
              ),
        isDense: true,
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

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.categoryLabel,
    required this.methodLabel,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> expense;
  final String categoryLabel;
  final String methodLabel;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final note = (expense['note'] ?? '').toString();

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: t.dangerSoft,
              borderRadius: MqRadius.brMd,
              border: Border.all(color: t.dangerLine),
            ),
            child: Icon(Icons.shopping_cart_outlined, color: t.danger, size: 20),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmtIQD(expense['amount']),
                    style: MqTypography.mono(
                        color: t.danger, size: 16, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    TeacherStatusPill(
                        label: categoryLabel, tone: TeacherTone.neutral),
                    const SizedBox(width: MqSpacing.xs),
                    Text(methodLabel,
                        style:
                            context.text.labelSmall?.copyWith(color: mq.ink3)),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: mq.ink2)),
                ],
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.event_outlined, size: 12, color: mq.ink3),
                    const SizedBox(width: MqSpacing.xs),
                    Text(fmtDate(expense['expense_date']),
                        style:
                            context.text.labelSmall?.copyWith(color: mq.ink3)),
                  ],
                ),
              ],
            ),
          ),
          _IconBtn(
              icon: Icons.edit_outlined, color: mq.ink2, onTap: onEdit),
          const SizedBox(width: MqSpacing.xs),
          _IconBtn(
              icon: Icons.delete_outline_rounded, color: mq.error, onTap: onDelete),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Material(
      color: mq.fill,
      shape: RoundedRectangleBorder(
        borderRadius: MqRadius.brSm,
        side: BorderSide(color: mq.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: mq.fill2, shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_outlined, size: 34, color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.md),
          Text(
            hasFilter
                ? 'لا توجد مصاريف بهذه الفلاتر'
                : 'لا توجد مصاريف بعد',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: mq.ink2),
          ),
          const SizedBox(height: MqSpacing.xs),
          Text(
            'أضف مصروفاً من زر «إضافة مصروف»',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: mq.ink3),
          ),
        ],
      ),
    );
  }
}
