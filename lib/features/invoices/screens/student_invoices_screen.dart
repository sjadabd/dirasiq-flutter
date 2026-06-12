// Student → Invoices / bills (MulhimIQ design-system pass).
//
// Read-only surface: the app has NO student-side payment flow for invoices
// (the only Wayl checkout in the app is video-course purchase), so there is no
// "دفع الآن" action here — tapping an invoice opens its read-only details.
// The fetch + study-year + status filtering all hit the backend unchanged;
// only the presentation was restyled. The `status` filter values map 1:1 to
// the server query param (pending / partial / paid / overdue); there is no
// "cancelled" status, so a ملغاة chip is intentionally not shown.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class StudentInvoicesScreen extends StatefulWidget {
  const StudentInvoicesScreen({super.key});

  @override
  State<StudentInvoicesScreen> createState() => _StudentInvoicesScreenState();
}

class _StudentInvoicesScreenState extends State<StudentInvoicesScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  String? _studyYear;
  String? _courseId;
  String? _status;

  final _money = NumberFormat('#,##0', 'en_US');

  List<Map<String, dynamic>> _invoices = [];
  double? _rTotalDue;
  double? _rTotalPaid;
  double? _rTotalRemain;

  static const List<(String?, String)> _statusChips = [
    (null, 'الكل'),
    ('pending', 'قيد السداد'),
    ('partial', 'سداد جزئي'),
    ('paid', 'مدفوعة'),
    ('overdue', 'متأخرة'),
  ];

  String _currentStudyYear() {
    final now = DateTime.now();
    final startYear = now.month >= 9 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

  @override
  void initState() {
    super.initState();
    try {
      final args = Get.arguments;
      if (args is Map) {
        final map = Map<String, dynamic>.from(args);
        final courseArg = map['courseId']?.toString();
        final yearArg = map['studyYear']?.toString();
        if (courseArg != null && courseArg.isNotEmpty) _courseId = courseArg;
        if (yearArg != null && yearArg.isNotEmpty) _studyYear = yearArg;
      }
    } catch (_) {}
    _studyYear ??= _currentStudyYear();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.fetchStudentInvoices(
        studyYear: _studyYear,
        courseId: _courseId,
        status: _status,
        page: 1,
        limit: 100,
      );
      final data = res['data'];
      List<Map<String, dynamic>> items = [];
      double? rDue, rPaid, rRemain;

      if (data is Map<String, dynamic>) {
        final list = (data['invoices'] ?? data['items'] ?? data['data'] ?? []) as List;
        items = List<Map<String, dynamic>>.from(list);
        final report = data['report'];
        if (report is Map<String, dynamic>) {
          rDue = _toDouble(report['total_amount_due']);
          rPaid = _toDouble(report['total_paid']);
          rRemain = _toDouble(report['total_remaining']);
        }
      } else if (data is List) {
        items = List<Map<String, dynamic>>.from(data);
      }

      setState(() {
        _invoices = items;
        _rTotalDue = rDue;
        _rTotalPaid = rPaid;
        _rTotalRemain = rRemain;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الفواتير');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  double _sumField(String key) {
    double s = 0;
    for (final inv in _invoices) {
      s += _toDouble(inv[key]);
    }
    return s;
  }

  String _money2(double v) => '${_money.format(v)} د.ع';

  String _formatDate(dynamic v) {
    if (v == null || v.toString().isEmpty) return 'غير محدد';
    try {
      return DateFormat('yyyy/MM/dd').format(DateTime.parse(v.toString()).toLocal());
    } catch (_) {
      return v.toString().split('T').first;
    }
  }

  String _statusLabel(String s) => switch (s) {
        'paid' => 'مدفوعة',
        'partial' => 'سداد جزئي',
        'overdue' => 'متأخرة',
        _ => 'قيد السداد',
      };

  (MqBadgeTone, Color) _statusTone(BuildContext context, String s) {
    final m = context.mq;
    return switch (s) {
      'paid' => (MqBadgeTone.success, m.success),
      'partial' => (MqBadgeTone.accent, m.accent),
      'overdue' => (MqBadgeTone.error, m.error),
      _ => (MqBadgeTone.orange, m.orange),
    };
  }

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.mq.page,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('فواتيري'),
                  Text('تابع مدفوعاتك ورسوم الدورات', style: context.text.bodySmall),
                ],
              ),
            ),
            body: RefreshIndicator(onRefresh: _load, child: _body(context)),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return _skeleton(context);
    if (_error != null) return _errorView(context);

    final totalDue = _rTotalDue ?? _sumField('amount_due');
    final totalPaid = _rTotalPaid ?? _sumField('amount_paid');
    final totalRemain = _rTotalRemain ?? _sumField('remaining_amount');
    final overdueCount = _invoices
        .where((i) => (i['invoice_status'] ?? i['status'] ?? '').toString() == 'overdue')
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxxl + MqSpacing.xl),
      children: [
        if (_invoices.isNotEmpty) ...[
          Row(children: [
            Expanded(child: _summaryCard(context, _money2(totalDue), 'إجمالي المطلوب', context.mq.accent, Icons.receipt_long_rounded)),
            MqSpacing.gapSm,
            Expanded(child: _summaryCard(context, _money2(totalPaid), 'المدفوع', context.mq.success, Icons.payments_rounded)),
          ]),
          MqSpacing.gapSm,
          Row(children: [
            Expanded(child: _summaryCard(context, _money2(totalRemain), 'المتبقي', context.mq.orange, Icons.account_balance_wallet_outlined)),
            MqSpacing.gapSm,
            Expanded(child: _summaryCard(context, '$overdueCount', 'الفواتير المتأخرة', context.mq.error, Icons.warning_amber_rounded)),
          ]),
          MqSpacing.gapLg,
        ],
        SizedBox(
          height: MqSize.chipHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _statusChips.length,
            separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.xs),
            itemBuilder: (_, i) {
              final (value, label) = _statusChips[i];
              return MqChip(
                label: label,
                selected: _status == value,
                onTap: () {
                  if (_status == value) return;
                  setState(() => _status = value);
                  _load();
                },
              );
            },
          ),
        ),
        MqSpacing.gapMd,
        if (_invoices.isEmpty)
          _empty(context)
        else
          for (final inv in _invoices)
            Padding(
              padding: const EdgeInsets.only(bottom: MqSpacing.sm),
              child: _invoiceCard(context, inv),
            ),
      ],
    );
  }

  Widget _summaryCard(BuildContext context, String value, String label, Color color, IconData icon) {
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: MqSize.iconMd),
          MqSpacing.gapXs,
          Text(value,
              style: context.text.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _invoiceCard(BuildContext context, Map<String, dynamic> inv) {
    final m = context.mq;
    final status = (inv['invoice_status'] ?? inv['status'] ?? '').toString();
    final (tone, color) = _statusTone(context, status);
    final due = _toDouble(inv['amount_due']);
    final paid = _toDouble(inv['amount_paid']);
    final remain = _toDouble(inv['remaining_amount']);
    final hasPaid = inv.containsKey('amount_paid') && inv['amount_paid'] != null;
    final hasRemain = inv.containsKey('remaining_amount') && inv['remaining_amount'] != null;
    final dueDate = _formatDate(inv['due_date'] ?? inv['dueDate']);
    final courseName = (inv['course_name'] ?? '').toString();
    final teacherName = (inv['teacher_name'] ?? '').toString();
    final invNo = (inv['invoice_number'] ?? inv['invoice_no'] ?? inv['number'] ?? '').toString();
    final id = inv['id']?.toString() ?? '';

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      onTap: id.isEmpty ? null : () => Get.toNamed('/invoice-details', arguments: id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: MqRadius.brMd),
                child: Icon(Icons.receipt_long_rounded, color: color, size: MqSize.iconSm),
              ),
              MqSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseName.isNotEmpty ? courseName : (invNo.isNotEmpty ? 'فاتورة #$invNo' : 'فاتورة'),
                      style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (teacherName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(teacherName, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ] else if (invNo.isNotEmpty && courseName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('#$invNo', style: context.text.labelSmall),
                    ],
                  ],
                ),
              ),
              MqSpacing.gapSm,
              MqBadge(label: _statusLabel(status), tone: tone),
            ],
          ),
          MqSpacing.gapMd,
          MqSurface(
            tone: MqSurfaceTone.neutral,
            padding: const EdgeInsets.all(MqSpacing.sm),
            child: Column(
              children: [
                _amountRow(context, 'قيمة الفاتورة', _money2(due), m.ink),
                if (hasPaid) ...[
                  const SizedBox(height: 4),
                  _amountRow(context, 'المدفوع', _money2(paid), m.success),
                ],
                if (hasRemain) ...[
                  const SizedBox(height: 4),
                  _amountRow(context, 'المتبقي', _money2(remain), m.orange),
                ],
              ],
            ),
          ),
          MqSpacing.gapSm,
          Row(
            children: [
              Icon(Icons.event_outlined, size: 13, color: m.ink3),
              MqSpacing.gapXxs,
              Text('الاستحقاق: $dueDate', style: context.text.labelSmall),
              const Spacer(),
              Text('عرض التفاصيل',
                  style: context.text.labelMedium?.copyWith(color: m.accent, fontWeight: FontWeight.w600)),
              Icon(Icons.chevron_left_rounded, size: 18, color: m.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountRow(BuildContext context, String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.text.labelSmall),
        Text(value, style: context.text.labelMedium?.copyWith(color: valueColor, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── states ──────────────────────────────────────────────────────────────────

  Widget _empty(BuildContext context) {
    final m = context.mq;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MqSpacing.xxl),
      child: Center(child: Column(children: [
        Container(
          padding: const EdgeInsets.all(MqSpacing.lg),
          decoration: BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
          child: Icon(Icons.receipt_long_rounded, size: 44, color: m.accent),
        ),
        MqSpacing.gapMd,
        Text('لا توجد فواتير', style: context.text.titleMedium),
        MqSpacing.gapXs,
        Text('ستظهر هنا فواتير ورسوم دوراتك.', textAlign: TextAlign.center, style: context.text.bodySmall),
      ])),
    );
  }

  Widget _errorView(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 44, color: m.error),
          MqSpacing.gapMd,
          Text(_error ?? 'حدث خطأ', textAlign: TextAlign.center, style: context.text.bodyMedium),
          MqSpacing.gapMd,
          MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: _load),
        ])),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    Widget block(double h) => Container(height: h, decoration: BoxDecoration(color: m.fill2, borderRadius: MqRadius.brLg));
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        Row(children: [Expanded(child: block(72)), MqSpacing.gapSm, Expanded(child: block(72))]),
        MqSpacing.gapSm,
        Row(children: [Expanded(child: block(72)), MqSpacing.gapSm, Expanded(child: block(72))]),
        MqSpacing.gapLg,
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.sm),
            child: MqCard(
              padding: const EdgeInsets.all(MqSpacing.md),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: m.fill2, borderRadius: MqRadius.brMd)),
                MqSpacing.gapMd,
                Expanded(child: block(46)),
              ]),
            ),
          ),
      ],
    );
  }
}
