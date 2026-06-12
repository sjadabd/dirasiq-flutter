import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';

/// Teacher → "فواتير عربون الطلاب" (Teacher Design System pass).
///
/// Presentation only — `fetchReservationPayments`, `markReservationPaid`,
/// `fetchAcademicYears`, the client-side filter/search, and the mark-paid
/// confirmation flow are UNCHANGED. Restyled to the teacher design system:
/// hero + year selector, KPI grid, MqChip filters, redesigned payment cards.
class TeacherReservationPaymentsScreen extends StatefulWidget {
  const TeacherReservationPaymentsScreen({super.key});

  @override
  State<TeacherReservationPaymentsScreen> createState() =>
      _TeacherReservationPaymentsScreenState();
}

class _TeacherReservationPaymentsScreenState
    extends State<TeacherReservationPaymentsScreen> {
  final TeacherApiService _api = TeacherApiService();

  List<String> _years = [];
  String? _studyYear;
  String? _activeStudyYear;

  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _report = const {};

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
      final data =
          (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
      final years = (data['years'] is List) ? (data['years'] as List) : [];
      _years = years
          .map((y) => (y is Map ? (y['year']?.toString() ?? '') : y.toString()))
          .where((s) => s.isNotEmpty)
          .toList()
          .cast<String>();
      _activeStudyYear =
          (data['active'] is Map) ? data['active']['year']?.toString() : null;
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
        limit: 100,
      );
      final data =
          (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
      final items = (data['items'] is List) ? (data['items'] as List) : [];
      _items =
          items.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      _report =
          (data['report'] is Map) ? Map<String, dynamic>.from(data['report']) : const {};
    } catch (e) {
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
        content: Text(
            'سيتم تسجيل عربون $student بمبلغ $amount د.ع كمدفوع.\nلا يمكن التراجع بعد التسديد.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.markReservationPaid(bookingId);
      Get.snackbar('تم', 'سُجّل العربون كمدفوع',
          snackPosition: SnackPosition.BOTTOM);
      await _fetch();
    } catch (e) {
      Get.snackbar('خطأ', 'تعذّر تسجيل العربون',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    final q = _searchTerm.trim().toLowerCase();
    return _items.where((it) {
      if (_statusFilter != null &&
          (it['status']?.toString() ?? '') != _statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      final name = (it['studentName'] ?? '').toString().toLowerCase();
      final course = (it['courseName'] ?? '').toString().toLowerCase();
      return name.contains(q) || course.contains(q);
    }).toList();
  }

  String _fmt(dynamic n) {
    if (n == null) return '0';
    final v = (n is num) ? n : num.tryParse(n.toString());
    if (v == null) return '0';
    return v
        .toInt()
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    final d = DateTime.tryParse(v.toString());
    if (d == null) {
      return v.toString().substring(0, v.toString().length.clamp(0, 10));
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _initials(String name) {
    if (name.isEmpty) return '؟';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first;
    return parts.first.characters.first + parts.last.characters.first;
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
          final totals = (_report['totals'] is Map)
              ? Map<String, dynamic>.from(_report['totals'])
              : const {};
          final counts = (_report['counts'] is Map)
              ? Map<String, dynamic>.from(_report['counts'])
              : const {};

          return Scaffold(
            backgroundColor: mq.page,
            appBar: TeacherAppBar(
              title: 'فواتير العربون',
              actions: [
                _RefreshAction(loading: _loading, onTap: _fetch),
              ],
            ),
            drawer: const TeacherDrawer(),
            body: RefreshIndicator(
              onRefresh: _fetch,
              color: mq.accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xl),
                children: [
                  _hero(context),
                  const SizedBox(height: MqSpacing.lg),
                  _kpiGrid(context, totals, counts),
                  const SizedBox(height: MqSpacing.lg),
                  _filters(context),
                  const SizedBox(height: MqSpacing.md),
                  _search(context),
                  const SizedBox(height: MqSpacing.lg),
                  if (_loading && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(MqSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_filteredItems.isEmpty)
                    _EmptyState(
                        hasFilter:
                            _statusFilter != null || _searchTerm.isNotEmpty)
                  else
                    ..._filteredItems.map((it) => Padding(
                          padding: const EdgeInsets.only(bottom: MqSpacing.md),
                          child: _PaymentCard(
                            item: it,
                            fmt: _fmt,
                            fmtDate: _fmtDate,
                            initials: _initials,
                            onMarkPaid: () => _confirmMarkPaid(it),
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
            child: const Icon(Icons.local_atm_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('فواتير العربون',
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

  Widget _kpiGrid(BuildContext context, Map totals, Map counts) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: MqSpacing.md,
      mainAxisSpacing: MqSpacing.md,
      childAspectRatio: 1.3,
      children: [
        TeacherKpiCard(
          label: 'إجمالي العربون',
          value: _fmt(totals['totalAmount']),
          icon: Icons.account_balance_outlined,
          tone: TeacherTone.info,
          caption: 'المتوقّع',
        ),
        TeacherKpiCard(
          label: 'المُستلَم',
          value: _fmt(totals['totalPaidAmount']),
          icon: Icons.check_circle_outline,
          tone: TeacherTone.success,
          caption: '${_fmt(counts['totalPaid'])} مدفوع',
        ),
        TeacherKpiCard(
          label: 'المتبقّي',
          value: _fmt(totals['remainingAmount']),
          icon: Icons.hourglass_top_outlined,
          tone: TeacherTone.warning,
          caption: '${_fmt(counts['totalPending'])} معلّق',
        ),
        TeacherKpiCard(
          label: 'الخصومات',
          value: _fmt(totals['discountAmount']),
          icon: Icons.percent_outlined,
          tone: TeacherTone.neutral,
          caption: 'مجموع',
        ),
      ],
    );
  }

  // ---- filters + search -----------------------------------------------------

  Widget _filters(BuildContext context) {
    final items = <(String?, String)>[
      (null, 'الكل'),
      ('paid', 'مدفوع'),
      ('pending', 'معلّق'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in items) ...[
            MqChip(
              label: label,
              selected: _statusFilter == value,
              onTap: () => setState(() => _statusFilter = value),
            ),
            const SizedBox(width: MqSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _search(BuildContext context) {
    return TextField(
      controller: _searchCtl,
      onChanged: (v) => setState(() => _searchTerm = v),
      decoration: InputDecoration(
        hintText: 'بحث عن طالب أو كورس...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchTerm.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchCtl.clear();
                  setState(() => _searchTerm = '');
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

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.item,
    required this.fmt,
    required this.fmtDate,
    required this.initials,
    required this.onMarkPaid,
  });
  final Map<String, dynamic> item;
  final String Function(dynamic) fmt;
  final String Function(dynamic) fmtDate;
  final String Function(String) initials;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final status = (item['status'] ?? '').toString();
    final isPaid = status == 'paid';
    final tone = isPaid ? TeacherTone.success : TeacherTone.warning;
    final base = isPaid ? t.success : t.warning;
    final soft = isPaid ? t.successSoft : t.warningSoft;
    final line = isPaid ? t.successLine : t.warningLine;
    final studentName = (item['studentName'] ?? '—').toString();
    final courseName = (item['courseName'] ?? '—').toString();

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: soft,
                  shape: BoxShape.circle,
                  border: Border.all(color: line),
                ),
                alignment: Alignment.center,
                child: Text(initials(studentName),
                    style: MqTypography.mono(
                        color: base, size: 15, weight: FontWeight.w700)),
              ),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall
                            ?.copyWith(color: mq.ink2)),
                  ],
                ),
              ),
              const SizedBox(width: MqSpacing.sm),
              TeacherStatusPill(
                  label: isPaid ? 'مدفوع' : 'معلّق', tone: tone),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: MqSpacing.md, vertical: MqSpacing.sm),
            decoration: BoxDecoration(
              color: mq.fill,
              borderRadius: MqRadius.brMd,
            ),
            child: Row(
              children: [
                _MetaCell(
                  icon: Icons.payments_outlined,
                  label: 'المبلغ',
                  value: '${fmt(item['amount'])} د.ع',
                  valueColor: mq.ink,
                  mono: true,
                ),
                Container(width: 1, height: 30, color: mq.line),
                _MetaCell(
                  icon: Icons.event_outlined,
                  label: 'تاريخ الدفع',
                  value: fmtDate(item['paidAt']),
                  valueColor: mq.ink2,
                ),
              ],
            ),
          ),
          if (!isPaid) ...[
            const SizedBox(height: MqSpacing.md),
            MqButton(
              label: 'تسديد العربون',
              icon: Icons.check_circle_outline,
              onPressed: onMarkPaid,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    this.mono = false,
  });
  final IconData icon;
  final String label, value;
  final Color valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: mq.ink3),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        context.text.labelSmall?.copyWith(color: mq.ink3)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mono
                      ? MqTypography.mono(
                          color: valueColor, size: 13, weight: FontWeight.w700)
                      : context.text.labelMedium
                          ?.copyWith(color: valueColor, fontWeight: FontWeight.w600),
                ),
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
                ? 'لا توجد نتائج بهذه الفلاتر'
                : 'لا توجد فواتير عربون في هذه السنة',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: mq.ink2),
          ),
        ],
      ),
    );
  }
}
