// Student → Invoice details (MulhimIQ design-system pass).
//
// Read-only: there is no student-side invoice payment flow, so no "دفع الآن"
// button is shown. Fetch + navigation to the installment screen are unchanged;
// only the presentation was restyled (the fl_chart pie was replaced with a
// design-system paid/discount/remaining breakdown bar).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'installment_details_screen.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final String invoiceId;
  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic>? _totals;

  final _money = NumberFormat('#,##0', 'en_US');

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  String _money2(double v) => '${_money.format(v)} د.ع';

  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return '';
    try {
      return DateFormat('yyyy/MM/dd').format(DateTime.parse(date.toString()).toLocal());
    } catch (_) {
      return date.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.fetchStudentInvoiceFull(widget.invoiceId);
      setState(() {
        _invoice = Map<String, dynamic>.from(data['invoice'] ?? {});
        _payments = List<Map<String, dynamic>>.from((data['payments'] ?? []) as List);
        _totals = data['totals'] is Map<String, dynamic> ? Map<String, dynamic>.from(data['totals']) : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الفاتورة');
    } finally {
      if (mounted) setState(() => _loading = false);
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

  String _paymentModeLabel(String mode) => switch (mode) {
        'installments' => 'أقساط',
        'full' => 'دفعة واحدة',
        _ => mode,
      };

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
            appBar: AppBar(title: const Text('تفاصيل الفاتورة')),
            body: _loading
                ? _skeleton(context)
                : _error != null
                    ? _errorView(context)
                    : _invoice == null
                        ? Center(child: Text('تعذّر تحميل الفاتورة', style: context.text.bodyMedium))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxxl),
                              children: [
                                _headerCard(context, _invoice!),
                                if (_totals != null) ...[
                                  MqSpacing.gapMd,
                                  _breakdownCard(context),
                                ],
                                if (_payments.isNotEmpty) ...[
                                  MqSpacing.gapMd,
                                  _paymentsSection(context),
                                ],
                              ],
                            ),
                          ),
          ),
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context, Map<String, dynamic> inv) {
    final m = context.mq;
    final status = (inv['invoice_status'] ?? inv['status'] ?? '').toString();
    final (tone, color) = _statusTone(context, status);
    final due = _toDouble(inv['amount_due']);
    final invoiceDate = _formatDate(inv['invoice_date'] ?? inv['created_at']);
    final dueDate = _formatDate(inv['due_date']);
    final paymentMode = (inv['payment_mode'] ?? '').toString();
    final courseName = (inv['course_name'] ?? '').toString();
    final teacherName = (inv['teacher_name'] ?? '').toString();
    final invNo = (inv['invoice_number'] ?? inv['invoice_no'] ?? inv['number'] ?? '').toString();
    final notes = (inv['notes'] ?? '').toString();

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: MqRadius.brMd),
                child: Icon(Icons.receipt_long_rounded, color: color, size: MqSize.iconMd),
              ),
              MqSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_money2(due), style: context.text.titleMedium),
                    if (invNo.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('فاتورة #$invNo', style: context.text.labelSmall),
                    ],
                  ],
                ),
              ),
              MqBadge(label: _statusLabel(status), tone: tone),
            ],
          ),
          MqSpacing.gapMd,
          if (courseName.isNotEmpty) _infoRow(context, Icons.book_outlined, 'الكورس', courseName),
          if (teacherName.isNotEmpty) _infoRow(context, Icons.person_outline_rounded, 'المعلم', teacherName),
          if (paymentMode.isNotEmpty) _infoRow(context, Icons.payments_outlined, 'طريقة الدفع', _paymentModeLabel(paymentMode)),
          if (invoiceDate.isNotEmpty) _infoRow(context, Icons.calendar_today_outlined, 'تاريخ الفاتورة', invoiceDate),
          if (dueDate.isNotEmpty) _infoRow(context, Icons.event_outlined, 'تاريخ الاستحقاق', dueDate),
          if (notes.isNotEmpty) ...[
            MqSpacing.gapSm,
            MqSurface(
              tone: MqSurfaceTone.neutral,
              padding: const EdgeInsets.all(MqSpacing.sm),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.sticky_note_2_outlined, size: 14, color: m.ink3),
                MqSpacing.gapXs,
                Expanded(child: Text(notes, style: context.text.bodySmall)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    final m = context.mq;
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.xs),
      child: Row(children: [
        Icon(icon, size: 14, color: m.accent),
        MqSpacing.gapXs,
        Text('$label: ', style: context.text.labelSmall),
        Expanded(child: Text(value, style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _breakdownCard(BuildContext context) {
    final m = context.mq;
    final t = _totals!;
    final paid = _toDouble(t['total_paid']);
    final disc = _toDouble(t['total_discount']);
    final remain = _toDouble(t['total_remaining']);
    final sum = paid + disc + remain;
    final progress = sum <= 0 ? 0.0 : ((paid + disc) / sum).clamp(0.0, 1.0);

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ملخّص السداد', style: context.text.titleSmall),
          MqSpacing.gapSm,
          MqLinearProgress(value: progress, tone: MqProgressTone.success, showLabel: true),
          MqSpacing.gapMd,
          Row(children: [
            Expanded(child: _statCell(context, _money2(paid), 'مدفوع', m.success)),
            Expanded(child: _statCell(context, _money2(disc), 'خصم', m.orange)),
            Expanded(child: _statCell(context, _money2(remain), 'متبقي', m.error)),
          ]),
        ],
      ),
    );
  }

  Widget _statCell(BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: context.text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label, style: context.text.labelSmall),
      ],
    );
  }

  Widget _paymentsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: MqSpacing.sm, right: MqSpacing.xxs),
          child: Text('جدول الدفعات', style: context.text.titleSmall),
        ),
        for (final p in _payments)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.sm),
            child: _paymentCard(context, p),
          ),
      ],
    );
  }

  Widget _paymentCard(BuildContext context, Map<String, dynamic> p) {
    final m = context.mq;
    final payNo = (p['payment_number'] ?? '').toString();
    final planned = _toDouble(p['planned_amount']);
    final paid = _toDouble(p['paid_amount']);
    final disc = _toDouble(p['discount_amount']);
    final remain = _toDouble(p['remaining_amount']);
    final status = (p['status'] ?? '').toString();
    final (tone, _) = _statusTone(context, status);
    final dueDate = _formatDate(p['due_date']);
    final paidDate = _formatDate(p['paid_date']);
    final instId = (p['installment_id'] ?? '').toString();

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      onTap: instId.isEmpty
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => InstallmentDetailsScreen(invoiceId: widget.invoiceId, installmentId: instId),
              )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('قسط ${payNo.isNotEmpty ? payNo : '-'}', style: context.text.titleSmall),
            MqSpacing.gapSm,
            MqBadge(label: _statusLabel(status), tone: tone),
            const Spacer(),
            if (dueDate.isNotEmpty) ...[
              Icon(Icons.event_outlined, size: 13, color: m.ink3),
              MqSpacing.gapXxs,
              Text(dueDate, style: context.text.labelSmall),
            ],
          ]),
          MqSpacing.gapSm,
          Row(children: [
            Expanded(child: _statCell(context, _money2(planned), 'المخطط', m.accent)),
            Expanded(child: _statCell(context, _money2(paid), 'المدفوع', m.success)),
            Expanded(child: _statCell(context, _money2(disc), 'الخصم', m.orange)),
            Expanded(child: _statCell(context, _money2(remain), 'المتبقي', m.error)),
          ]),
          if (paidDate.isNotEmpty) ...[
            MqSpacing.gapSm,
            Row(children: [
              Icon(Icons.check_circle_outline_rounded, size: 13, color: m.success),
              MqSpacing.gapXxs,
              Text('تاريخ الدفع: $paidDate', style: context.text.labelSmall),
            ]),
          ],
          MqSpacing.gapSm,
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('عرض المزيد',
                style: context.text.labelMedium?.copyWith(color: m.accent, fontWeight: FontWeight.w600)),
            Icon(Icons.chevron_left_rounded, size: 18, color: m.accent),
          ]),
        ],
      ),
    );
  }

  // ── states ──────────────────────────────────────────────────────────────────

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
      children: [block(120), MqSpacing.gapMd, block(110), MqSpacing.gapMd, block(140)],
    );
  }
}
