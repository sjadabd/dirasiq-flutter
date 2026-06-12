import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_helpers.dart' show fmtNum, fmtIQDShort, initialsOf;
import 'teacher_invoice_detail_screen.dart';
import 'widgets/teacher_invoice_form_sheet.dart';

/// Teacher → "فواتير الطلاب" (Teacher Design System pass).
///
/// Presentation only — `fetchInvoices` / `fetchInvoicesSummary`,
/// `addInvoicePayment`, `setInvoiceDiscount`, `deleteInvoice`, the server-side
/// status filter, and the search are UNCHANGED. Restyled to the teacher design
/// system: hero + year selector, KPI grid, MqChip filters, redesigned invoice
/// cards with the same payment/discount/delete actions.
class TeacherInvoicesScreen extends StatefulWidget {
  const TeacherInvoicesScreen({super.key});
  @override
  State<TeacherInvoicesScreen> createState() => _TeacherInvoicesScreenState();
}

class _TeacherInvoicesScreenState extends State<TeacherInvoicesScreen> {
  final _api = TeacherApiService();

  List<String> _years = [];
  String? _studyYear;
  String? _activeYear;
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _summary = const {};
  String? _statusFilter;
  String _search = '';
  final _searchCtl = TextEditingController();

  static const _filters = <(String?, String)>[
    (null, 'الكل'),
    ('paid', 'مدفوعة'),
    ('partial', 'جزئية'),
    ('pending', 'معلّقة'),
    ('overdue', 'متأخرة'),
  ];

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
      final data =
          (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
      final years = (data['years'] is List) ? (data['years'] as List) : [];
      _years = years
          .map((y) => (y is Map ? (y['year']?.toString() ?? '') : y.toString()))
          .where((s) => s.isNotEmpty)
          .cast<String>()
          .toList();
      _activeYear = (data['active'] is Map)
          ? data['active']['year']?.toString()
          : (_years.isNotEmpty ? _years.first : null);
      _studyYear = _activeYear;
      if (mounted) setState(() {});
    } catch (_) {}
    await _fetch();
  }

  Future<void> _fetch() async {
    if (_studyYear == null) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.fetchInvoices(
            studyYear: _studyYear!,
            status: _statusFilter,
            search: _search.trim().isEmpty ? null : _search.trim(),
            page: 1,
            limit: 100),
        _api.fetchInvoicesSummary(studyYear: _studyYear!, status: _statusFilter),
      ]);
      final list = results[0]['data'];
      _items = (list is List)
          ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : [];
      final s = results[1]['data'];
      _summary = s is Map ? Map<String, dynamic>.from(s) : const {};
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب الفواتير',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(Map<String, dynamic> inv) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TeacherInvoiceDetailScreen(
          invoiceId: inv['id'].toString(),
          studentName: inv['student_name']?.toString(),
          courseName: inv['course_name']?.toString(),
        ),
      ),
    );
    if (changed == true) await _fetch();
  }

  Future<void> _openEdit(Map<String, dynamic> inv) async {
    // A full edit regenerates installments, so it's only valid before any
    // payment was collected. Block early with a clear message otherwise.
    final paid = num.tryParse((inv['amount_paid'] ?? 0).toString()) ?? 0;
    if (paid > 0) {
      Get.snackbar('غير ممكن',
          'لا يمكن تعديل فاتورة بدأ تحصيل دفعات منها. افتح العرض للتسديد.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    // Fetch the full invoice (with installments) so the form can prefill the
    // plan count / interval / first-due.
    List<Map<String, dynamic>> installments = const [];
    Map<String, dynamic> full = inv;
    try {
      final res = await _api.fetchInvoiceFull(inv['id'].toString());
      final data = (res['data'] is Map)
          ? Map<String, dynamic>.from(res['data'])
          : <String, dynamic>{};
      if (data['invoice'] is Map) {
        full = Map<String, dynamic>.from(data['invoice']);
      }
      final list = data['installments'];
      if (list is List) {
        installments = list
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {}
    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => TeacherInvoiceFormSheet(
        api: _api,
        studyYear: (full['study_year'] ?? _activeYear ?? _studyYear ?? '')
            .toString(),
        existing: full,
        existingInstallments: installments,
      ),
    );
    if (saved == true && mounted) {
      Get.snackbar('تم', 'تم تعديل الفاتورة وإشعار الطالب',
          snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    }
  }

  Future<void> _openCreateInvoice() async {
    final year = _activeYear ?? _studyYear;
    if (year == null) {
      Get.snackbar('تنبيه', 'لا توجد سنة دراسية مفعلة',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => TeacherInvoiceFormSheet(
        api: _api,
        studyYear: year,
      ),
    );
    if (created == true && mounted) {
      Get.snackbar('تم', 'تم إنشاء الفاتورة وإشعار الطالب',
          snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    }
  }

  Future<void> _delete(Map<String, dynamic> inv) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('تأكيد الحذف'),
              content: const Text('سيتم حذف الفاتورة. يمكن استرجاعها لاحقاً.'),
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

  static (String, TeacherTone) statusMeta(String? s) {
    switch (s) {
      case 'paid':
        return ('مدفوعة', TeacherTone.success);
      case 'partial':
        return ('جزئية', TeacherTone.info);
      case 'pending':
        return ('معلّقة', TeacherTone.warning);
      case 'overdue':
        return ('متأخرة', TeacherTone.danger);
      default:
        return ('الكل', TeacherTone.neutral);
    }
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
          return Scaffold(
            backgroundColor: mq.page,
            appBar: TeacherAppBar(
              title: 'فواتير الطلاب',
              actions: [_RefreshAction(loading: _loading, onTap: _fetch)],
            ),
            drawer: const TeacherDrawer(),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _loading ? null : _openCreateInvoice,
              backgroundColor: mq.accent,
              foregroundColor: mq.onAccent,
              elevation: 3,
              icon: const Icon(Icons.add_rounded),
              label: const Text('فاتورة جديدة'),
              shape: const RoundedRectangleBorder(borderRadius: MqRadius.brLg),
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
                  else if (_filtered.isEmpty)
                    _EmptyState(
                        hasFilter:
                            _statusFilter != null || _search.trim().isNotEmpty)
                  else
                    ..._filtered.map((inv) => Padding(
                          padding: const EdgeInsets.only(bottom: MqSpacing.md),
                          child: _InvoiceCard(
                            inv: inv,
                            onView: () => _openDetail(inv),
                            onEdit: () => _openEdit(inv),
                            onDelete: () => _delete(inv),
                          ),
                        )),
                  const SizedBox(height: MqSpacing.sm),
                  Text(
                    'لخطط الأقساط المخصّصة (مبلغ وتاريخ لكل قسط) استخدم لوحة التحكم على الويب.',
                    textAlign: TextAlign.center,
                    style: context.text.labelSmall?.copyWith(color: mq.ink3),
                  ),
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
            child: const Icon(Icons.receipt_long_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('فواتير الطلاب',
                    style: context.text.titleMedium?.copyWith(color: t.heroInk)),
                const SizedBox(height: 2),
                Text('السنة الدراسية: ${_studyYear ?? '—'}',
                    style:
                        context.text.labelSmall?.copyWith(color: t.heroInk2)),
              ],
            ),
          ),
          if (_years.length > 1) _yearSelector(context),
        ],
      ),
    );
  }

  Widget _yearSelector(BuildContext context) {
    final t = context.teacher;
    return PopupMenuButton<String>(
      initialValue: _studyYear,
      onSelected: (v) async {
        setState(() => _studyYear = v);
        await _fetch();
      },
      itemBuilder: (ctx) =>
          _years.map((y) => PopupMenuItem(value: y, child: Text(y))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: MqSpacing.md, vertical: MqSpacing.sm),
        decoration: BoxDecoration(
          color: t.heroTile,
          borderRadius: MqRadius.brPill,
          border: Border.all(color: t.heroLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.expand_more_rounded, color: t.heroInk, size: 16),
            const SizedBox(width: MqSpacing.xs),
            Text(_studyYear ?? 'السنة',
                style: context.text.labelSmall?.copyWith(color: t.heroInk)),
          ],
        ),
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
      childAspectRatio: 1.3,
      children: [
        TeacherKpiCard(
          label: 'إجمالي الفواتير',
          value: fmtIQDShort(_summary['totalAmount']),
          icon: Icons.receipt_long_outlined,
          tone: TeacherTone.info,
          caption: '${fmtNum(_summary['totalCount'])} فاتورة',
        ),
        TeacherKpiCard(
          label: 'المدفوع',
          value: fmtIQDShort(_summary['totalPaid']),
          icon: Icons.check_circle_outline,
          tone: TeacherTone.success,
          caption: '${fmtNum(_summary['paidCount'])} مدفوعة',
        ),
        TeacherKpiCard(
          label: 'المتبقّي',
          value: fmtIQDShort(_summary['totalRemaining']),
          icon: Icons.hourglass_top_outlined,
          tone: TeacherTone.warning,
          caption: '${fmtNum(_summary['pendingCount'])} معلّقة',
        ),
        TeacherKpiCard(
          label: 'الخصومات',
          value: fmtIQDShort(_summary['totalDiscount']),
          icon: Icons.percent_outlined,
          tone: TeacherTone.neutral,
          caption: '${fmtNum(_summary['discountCount'])} مع خصم',
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
          for (final (value, label) in _filters) ...[
            MqChip(
              label: label,
              selected: _statusFilter == value,
              onTap: () {
                setState(() => _statusFilter = value);
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
        hintText: 'بحث عن طالب أو كورس...',
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

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.inv,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> inv;
  final VoidCallback onView, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final status = (inv['invoice_status'] ?? '').toString();
    final (label, tone) = _TeacherInvoicesScreenState.statusMeta(status);
    final hasPayments =
        (num.tryParse((inv['amount_paid'] ?? 0).toString()) ?? 0) > 0;

    final (base, soft, line) = switch (tone) {
      TeacherTone.success => (t.success, t.successSoft, t.successLine),
      TeacherTone.warning => (t.warning, t.warningSoft, t.warningLine),
      TeacherTone.danger => (t.danger, t.dangerSoft, t.dangerLine),
      TeacherTone.info => (t.info, t.infoSoft, t.infoLine),
      TeacherTone.neutral => (mq.ink2, mq.fill2, mq.line),
    };

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: soft,
                  shape: BoxShape.circle,
                  border: Border.all(color: line),
                ),
                alignment: Alignment.center,
                child: Text(initialsOf(inv['student_name']?.toString()),
                    style: MqTypography.mono(
                        color: base, size: 14, weight: FontWeight.w700)),
              ),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((inv['student_name'] ?? '—').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text((inv['course_name'] ?? '—').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall
                            ?.copyWith(color: mq.ink2)),
                  ],
                ),
              ),
              const SizedBox(width: MqSpacing.sm),
              TeacherStatusPill(label: label, tone: tone),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: MqSpacing.md, vertical: MqSpacing.sm),
            decoration:
                BoxDecoration(color: mq.fill, borderRadius: MqRadius.brMd),
            child: Row(
              children: [
                _AmountCell(
                    label: 'المستحق',
                    value: fmtIQDShort(inv['amount_due']),
                    color: mq.ink),
                Container(width: 1, height: 28, color: mq.line),
                _AmountCell(
                    label: 'المدفوع',
                    value: fmtIQDShort(inv['amount_paid']),
                    color: t.success),
                Container(width: 1, height: 28, color: mq.line),
                _AmountCell(
                    label: 'المتبقّي',
                    value: fmtIQDShort(inv['remaining_amount']),
                    color: t.danger),
              ],
            ),
          ),
          const SizedBox(height: MqSpacing.md),
          Row(
            children: [
              Expanded(
                child: MqButton.secondary(
                  label: 'عرض',
                  icon: Icons.visibility_outlined,
                  size: MqButtonSize.small,
                  onPressed: onView,
                ),
              ),
              const SizedBox(width: MqSpacing.sm),
              if (!hasPayments) ...[
                Expanded(
                  child: MqButton.secondary(
                    label: 'تعديل',
                    icon: Icons.edit_outlined,
                    size: MqButtonSize.small,
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(width: MqSpacing.sm),
              ],
              _DangerIconButton(onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountCell extends StatelessWidget {
  const _AmountCell(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: context.text.labelSmall?.copyWith(color: mq.ink3)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: MqTypography.mono(
                    color: color, size: 14, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _DangerIconButton extends StatelessWidget {
  const _DangerIconButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Material(
      color: mq.error.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: MqRadius.brMd,
        side: BorderSide(color: mq.error.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: MqSize.buttonHeightSm,
          height: MqSize.buttonHeightSm,
          child: Icon(Icons.delete_outline_rounded,
              size: MqSize.iconSm, color: mq.error),
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
            decoration:
                BoxDecoration(color: mq.fill2, shape: BoxShape.circle),
            child: Icon(Icons.inbox_outlined, size: 34, color: mq.ink3),
          ),
          const SizedBox(height: MqSpacing.md),
          Text(
            hasFilter
                ? 'لا توجد فواتير بهذه الفلاتر'
                : 'لا توجد فواتير في هذه السنة',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: mq.ink2),
          ),
        ],
      ),
    );
  }
}
