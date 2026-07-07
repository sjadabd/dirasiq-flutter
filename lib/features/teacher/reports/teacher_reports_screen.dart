import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_helpers.dart' show fmtIQD, fmtIQDShort, adClickSpend;

/// Teacher → "التقارير المالية" (Teacher Design System pass).
///
/// Presentation only — `fetchFinancialReport` / `fetchAcademicYears` and the
/// study-year selector are UNCHANGED. Restyled to the teacher design system:
/// hero + year selector, KPI grid, and two breakdown cards (student invoices /
/// reservation invoices).
class TeacherReportsScreen extends StatefulWidget {
  const TeacherReportsScreen({super.key});
  @override
  State<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> {
  final _api = TeacherApiService();
  bool _loading = false;
  Map<String, dynamic> _report = const {};
  Map<String, dynamic> _adStats = const {};
  List<Map<String, dynamic>> _adItems = const [];
  String? _studyYear;
  List<String> _years = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
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
      _studyYear = (data['active'] is Map)
          ? data['active']['year']?.toString()
          : (_years.isNotEmpty ? _years.first : null);
    } catch (_) {}
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.fetchFinancialReport(studyYear: _studyYear),
        _api.fetchAdvertisementStatistics(),
        _api.fetchAdvertisements(limit: 100),
      ]);
      final res = results[0];
      final adStatsRes = results[1];
      final adListRes = results[2];
      _report = (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
      _adStats = Map<String, dynamic>.from(adStatsRes);
      final adData = adListRes['data'];
      if (adData is List) {
        _adItems = adData.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (adData is Map && adData['data'] is List) {
        _adItems = (adData['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        _adItems = const [];
      }
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب التقرير',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  num _n(dynamic v) => num.tryParse((v ?? 0).toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: isDark ? MqTheme.dark() : MqTheme.light(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: (context) {
          final mq = context.mq;

          final invoices = (_report['invoices'] is Map)
              ? Map<String, dynamic>.from(_report['invoices'])
              : const {};
          final student = (invoices['student'] is Map)
              ? Map<String, dynamic>.from(invoices['student'])
              : const {};
          final reservation = (invoices['reservation'] is Map)
              ? Map<String, dynamic>.from(invoices['reservation'])
              : const {};
          final expenses = (_report['expenses'] is Map)
              ? Map<String, dynamic>.from(_report['expenses'])
              : const {};
          final summary = (_report['summary'] is Map)
              ? Map<String, dynamic>.from(_report['summary'])
              : const {};
          final paidIncome = _n(summary['totalPaidIncome']);
          final dueIncome = _n(summary['totalDueIncome']);
          final exp = _n(expenses['total']);
          final netPaid = _n(summary['netProfitPaidBasis']); // الأرباح الحقيقية
          final netDue = _n(summary['netProfitDueBasis']); // الأرباح المتوقّعة
          final remaining =
              _n(student['totalRemaining']) + _n(reservation['totalRemaining']);
          final adSpent = _n(_adStats['totalMoneySpent']);
          final adRemaining = _n(_adStats['remainingBudget']);
          final adClicks = _n(_adStats['uniqueStudentClicks']);
          final adRunning = _n(_adStats['runningAdvertisements']);

          return Scaffold(
            backgroundColor: mq.page,
            appBar: TeacherAppBar(
              title: 'التقارير المالية',
              actions: [_RefreshAction(loading: _loading, onTap: _fetch)],
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
                  _kpiGrid(context, paidIncome, dueIncome, exp, remaining),
                  const SizedBox(height: MqSpacing.lg),
                  _profitsCard(context,
                      expected: netDue,
                      actual: netPaid,
                      due: dueIncome,
                      paid: paidIncome,
                      exp: exp),
                  const SizedBox(height: MqSpacing.md),
                  _breakdown(context,
                      title: 'فواتير الطلاب',
                      icon: Icons.receipt_long_outlined,
                      tone: TeacherTone.info,
                      data: student),
                  const SizedBox(height: MqSpacing.md),
                  _breakdown(context,
                      title: 'فواتير العربون',
                      icon: Icons.savings_outlined,
                      tone: TeacherTone.warning,
                      data: reservation),
                  const SizedBox(height: MqSpacing.md),
                  _adsSummaryCard(
                    context,
                    adSpent: adSpent,
                    adRemaining: adRemaining,
                    adClicks: adClicks,
                    adRunning: adRunning,
                  ),
                  const SizedBox(height: MqSpacing.md),
                  _adsBreakdownTable(context),
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
            child: const Icon(Icons.bar_chart_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التقرير المالي',
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

  Widget _kpiGrid(
      BuildContext context, num paid, num due, num exp, num remaining) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: MqSpacing.md,
      mainAxisSpacing: MqSpacing.md,
      childAspectRatio: 1.3,
      children: [
        TeacherKpiCard(
          label: 'الدخل المستحق',
          value: fmtIQDShort(due),
          icon: Icons.account_balance_outlined,
          tone: TeacherTone.info,
          caption: 'الفواتير + العربون',
        ),
        TeacherKpiCard(
          label: 'الدخل المقبوض',
          value: fmtIQDShort(paid),
          icon: Icons.payments_outlined,
          tone: TeacherTone.success,
          caption: 'محصّل فعلياً',
        ),
        TeacherKpiCard(
          label: 'المصاريف',
          value: fmtIQDShort(exp),
          icon: Icons.shopping_cart_outlined,
          tone: TeacherTone.danger,
          caption: 'إجمالي',
        ),
        TeacherKpiCard(
          label: 'المتبقّي للتحصيل',
          value: fmtIQDShort(remaining),
          icon: Icons.schedule_outlined,
          tone: TeacherTone.warning,
          caption: 'لم يُدفع بعد',
        ),
      ],
    );
  }

  // ---- expected vs actual profit -------------------------------------------

  Widget _profitsCard(
    BuildContext context, {
    required num expected,
    required num actual,
    required num due,
    required num paid,
    required num exp,
  }) {
    return Column(
      children: [
        _profitRow(
          context,
          title: 'الأرباح المتوقّعة',
          formula: 'الفواتير + العربون − المصاريف',
          value: expected,
          income: due,
          exp: exp,
          icon: Icons.insights_outlined,
        ),
        const SizedBox(height: MqSpacing.md),
        _profitRow(
          context,
          title: 'الأرباح الحقيقية',
          formula: 'المحصّل (فواتير + عربون) − المصاريف',
          value: actual,
          income: paid,
          exp: exp,
          icon: Icons.verified_outlined,
        ),
      ],
    );
  }

  Widget _profitRow(
    BuildContext context, {
    required String title,
    required String formula,
    required num value,
    required num income,
    required num exp,
    required IconData icon,
  }) {
    final t = context.teacher;
    final mq = context.mq;
    final positive = value >= 0;
    final base = positive ? t.success : t.danger;
    final soft = positive ? t.successSoft : t.dangerSoft;
    final line = positive ? t.successLine : t.dangerLine;

    return Container(
      padding: const EdgeInsets.all(MqSpacing.lg),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: MqRadius.brLg,
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(color: base, borderRadius: MqRadius.brMd),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: MqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: context.text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(formula,
                        style: context.text.labelSmall
                            ?.copyWith(color: mq.ink3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MqSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(fmtIQD(value),
                style: MqTypography.mono(
                    color: base, size: 24, weight: FontWeight.w800)),
          ),
          const SizedBox(height: MqSpacing.sm),
          Row(
            children: [
              Icon(Icons.add_circle_outline, size: 14, color: t.success),
              const SizedBox(width: 4),
              Text(fmtIQD(income),
                  style: context.text.labelSmall?.copyWith(color: mq.ink2)),
              const SizedBox(width: MqSpacing.md),
              Icon(Icons.remove_circle_outline, size: 14, color: t.danger),
              const SizedBox(width: 4),
              Text(fmtIQD(exp),
                  style: context.text.labelSmall?.copyWith(color: mq.ink2)),
            ],
          ),
        ],
      ),
    );
  }

  // ---- breakdown card -------------------------------------------------------

  Widget _breakdown(
    BuildContext context, {
    required String title,
    required IconData icon,
    required TeacherTone tone,
    required Map data,
  }) {
    final t = context.teacher;
    return TeacherDashboardCard(
      title: title,
      icon: icon,
      tone: tone,
      child: Column(
        children: [
          TeacherDataRow(
            label: 'المستحق',
            value: fmtIQD(data['totalDue']),
            icon: Icons.account_balance_wallet_outlined,
            iconTone: TeacherTone.info,
            mono: true,
          ),
          TeacherDataRow(
            label: 'الخصومات',
            value: fmtIQD(data['totalDiscount']),
            icon: Icons.percent_rounded,
            iconTone: TeacherTone.warning,
            valueColor: t.warning,
            mono: true,
          ),
          TeacherDataRow(
            label: 'المدفوع',
            value: fmtIQD(data['totalPaid']),
            icon: Icons.check_circle_outline,
            iconTone: TeacherTone.success,
            valueColor: t.success,
            mono: true,
          ),
          TeacherDataRow(
            label: 'المتبقّي',
            value: fmtIQD(data['totalRemaining']),
            icon: Icons.schedule_outlined,
            iconTone: TeacherTone.danger,
            valueColor: t.danger,
            mono: true,
          ),
        ],
      ),
    );
  }

  Widget _adsSummaryCard(
    BuildContext context, {
    required num adSpent,
    required num adRemaining,
    required num adClicks,
    required num adRunning,
  }) {
    final t = context.teacher;
    return TeacherDashboardCard(
      title: 'تقارير الإعلانات',
      icon: Icons.campaign_outlined,
      tone: TeacherTone.warning,
      child: Column(
        children: [
          TeacherDataRow(
            label: 'استقطاعات الإعلانات',
            value: fmtIQD(adSpent),
            icon: Icons.remove_circle_outline,
            iconTone: TeacherTone.danger,
            valueColor: t.danger,
            mono: true,
          ),
          TeacherDataRow(
            label: 'صافي المبلغ المتبقي',
            value: fmtIQD(adRemaining),
            icon: Icons.account_balance_wallet_outlined,
            iconTone: TeacherTone.success,
            valueColor: t.success,
            mono: true,
          ),
          TeacherDataRow(
            label: 'النقرات الفريدة',
            value: adClicks.toStringAsFixed(0),
            icon: Icons.touch_app_outlined,
            iconTone: TeacherTone.info,
          ),
          TeacherDataRow(
            label: 'إعلانات نشطة',
            value: adRunning.toStringAsFixed(0),
            icon: Icons.play_circle_outline,
            iconTone: TeacherTone.warning,
          ),
        ],
      ),
    );
  }

  Widget _adsBreakdownTable(BuildContext context) {
    if (_adItems.isEmpty) {
      return TeacherDashboardCard(
        title: 'تفاصيل الإعلانات',
        icon: Icons.table_rows_outlined,
        tone: TeacherTone.info,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: MqSpacing.md),
          child: Text('لا توجد إعلانات لعرض تفاصيلها'),
        ),
      );
    }

    String statusLabel(String status) {
      switch (status) {
        case 'draft':
          return 'مسودة';
        case 'pending_review':
          return 'قيد المراجعة';
        case 'approved':
          return 'موافق عليه';
        case 'running':
          return 'نشط';
        case 'rejected':
          return 'مرفوض';
        case 'finished':
          return 'منتهي';
        case 'budget_exhausted':
          return 'نفدت الميزانية';
        default:
          return status;
      }
    }

    return TeacherDashboardCard(
      title: 'تفاصيل الإعلانات',
      icon: Icons.table_rows_outlined,
      tone: TeacherTone.info,
      child: Column(
        children: _adItems.map((ad) {
          final spent = adClickSpend(ad);
          final rem = _n(ad['budgetRemaining'] ?? ad['budget_remaining']);
          final title = (ad['title'] ?? 'إعلان').toString();
          final status = statusLabel((ad['status'] ?? '').toString());
          return Container(
            margin: const EdgeInsets.only(bottom: MqSpacing.sm),
            padding: const EdgeInsets.all(MqSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(color: context.mq.line),
              borderRadius: MqRadius.brMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 4),
                Text('الحالة: $status', style: context.text.labelSmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text('مصروف النقرات: ${fmtIQD(spent)}',
                          style: context.text.labelSmall),
                    ),
                    Expanded(
                      child: Text('محجوز: ${fmtIQD(rem)}',
                          style: context.text.labelSmall),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
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
