// Student → Installment details (MulhimIQ design-system pass).
//
// Read-only payment-detail surface (partial payments + discounts on one
// installment). No student payment action exists, so no "دفع الآن" button.
// Fetch is unchanged; only the presentation was restyled.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class InstallmentDetailsScreen extends StatefulWidget {
  final String invoiceId;
  final String installmentId;
  const InstallmentDetailsScreen({
    super.key,
    required this.invoiceId,
    required this.installmentId,
  });

  @override
  State<InstallmentDetailsScreen> createState() => _InstallmentDetailsScreenState();
}

class _InstallmentDetailsScreenState extends State<InstallmentDetailsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _invoice;
  Map<String, dynamic>? _installment;
  List<Map<String, dynamic>> _partials = [];
  List<Map<String, dynamic>> _discounts = [];
  Map<String, dynamic>? _totals;

  final _money = NumberFormat('#,##0', 'en_US');

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  String _money2(double v) => '${_money.format(v)} د.ع';

  String _formatDate(dynamic v) {
    if (v == null || v.toString().isEmpty) return '';
    try {
      return DateFormat('yyyy/MM/dd').format(DateTime.parse(v.toString()).toLocal());
    } catch (_) {
      return v.toString();
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
      final data = await _api.fetchStudentInstallmentFull(
        invoiceId: widget.invoiceId,
        installmentId: widget.installmentId,
      );
      setState(() {
        _invoice = data['invoice'] is Map<String, dynamic> ? Map<String, dynamic>.from(data['invoice']) : null;
        _installment = data['installment'] is Map<String, dynamic> ? Map<String, dynamic>.from(data['installment']) : null;
        _partials = List<Map<String, dynamic>>.from((data['partials'] ?? []) as List);
        _discounts = List<Map<String, dynamic>>.from((data['discounts'] ?? []) as List);
        _totals = data['totals'] is Map<String, dynamic> ? Map<String, dynamic>.from(data['totals']) : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر تحميل القسط');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(String s) => switch (s) {
        'paid' => 'مدفوع',
        'partial' => 'سداد جزئي',
        'overdue' => 'متأخر',
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

  String _paymentMethodLabel(String method) => switch (method) {
        'cash' => 'نقدي',
        'card' => 'بطاقة',
        'transfer' => 'تحويل',
        _ => method,
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
            appBar: AppBar(title: const Text('تفاصيل القسط')),
            body: _loading
                ? _skeleton(context)
                : _error != null
                    ? _errorView(context)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                              MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxxl),
                          children: [
                            _headerCard(context),
                            if (_totals != null) ...[
                              MqSpacing.gapMd,
                              _breakdownCard(context),
                            ],
                            if (_partials.isNotEmpty) ...[
                              MqSpacing.gapMd,
                              _listSection(context, 'دفعات جزئية', _partials.map((p) => _partialTile(context, p)).toList()),
                            ],
                            if (_discounts.isNotEmpty) ...[
                              MqSpacing.gapMd,
                              _listSection(context, 'الخصومات', _discounts.map((d) => _discountTile(context, d)).toList()),
                            ],
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context) {
    final m = context.mq;
    final inv = _invoice ?? const {};
    final ins = _installment ?? const {};
    final courseName = (inv['course_name'] ?? '').toString();
    final teacherName = (inv['teacher_name'] ?? '').toString();
    final number = ins['payment_number']?.toString() ?? '-';
    final status = (ins['status'] ?? '').toString();
    final (tone, color) = _statusTone(context, status);
    final planned = _toDouble(ins['planned_amount']);
    final paid = _toDouble(ins['paid_amount']);
    final remain = _toDouble(ins['remaining_amount']);
    final dueDate = _formatDate(ins['due_date']);
    final paidDate = _formatDate(ins['paid_date']);

    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: MqRadius.brMd),
              child: Icon(Icons.payments_rounded, color: color, size: MqSize.iconMd),
            ),
            MqSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('قسط $number', style: context.text.titleMedium),
                  if (courseName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(courseName, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  if (teacherName.isNotEmpty)
                    Text(teacherName, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            MqBadge(label: _statusLabel(status), tone: tone),
          ]),
          MqSpacing.gapMd,
          Row(children: [
            Expanded(child: _statCell(context, _money2(planned), 'المخطط', m.accent)),
            Expanded(child: _statCell(context, _money2(paid), 'المدفوع', m.success)),
            Expanded(child: _statCell(context, _money2(remain), 'المتبقي', m.error)),
          ]),
          if (dueDate.isNotEmpty || paidDate.isNotEmpty) ...[
            MqSpacing.gapSm,
            Row(children: [
              if (dueDate.isNotEmpty) ...[
                Icon(Icons.event_outlined, size: 13, color: m.ink3),
                MqSpacing.gapXxs,
                Text('الاستحقاق: $dueDate', style: context.text.labelSmall),
              ],
              if (paidDate.isNotEmpty) ...[
                MqSpacing.gapMd,
                Icon(Icons.check_circle_outline_rounded, size: 13, color: m.success),
                MqSpacing.gapXxs,
                Text('الدفع: $paidDate', style: context.text.labelSmall),
              ],
            ]),
          ],
        ],
      ),
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
          Text('ملخّص القسط', style: context.text.titleSmall),
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
    return Column(children: [
      Text(value,
          style: context.text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label, style: context.text.labelSmall),
    ]);
  }

  Widget _listSection(BuildContext context, String title, List<Widget> tiles) {
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleSmall),
          MqSpacing.gapSm,
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) MqSpacing.gapSm,
            tiles[i],
          ],
        ],
      ),
    );
  }

  Widget _partialTile(BuildContext context, Map<String, dynamic> p) {
    final m = context.mq;
    final amount = _toDouble(p['amount']);
    final paidAt = _formatDate(p['paid_at']);
    final method = (p['payment_method'] ?? '').toString();
    final notes = (p['notes'] ?? '').toString();

    return MqSurface(
      tone: MqSurfaceTone.neutral,
      padding: const EdgeInsets.all(MqSpacing.sm),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: m.success.withValues(alpha: 0.14), borderRadius: MqRadius.brMd),
          child: Icon(Icons.payments_outlined, color: m.success, size: MqSize.iconSm),
        ),
        MqSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_money2(amount), style: context.text.titleSmall),
              Row(children: [
                if (paidAt.isNotEmpty) ...[
                  Icon(Icons.calendar_today_outlined, size: 11, color: m.ink3),
                  MqSpacing.gapXxs,
                  Text(paidAt, style: context.text.labelSmall),
                ],
                if (method.isNotEmpty) ...[
                  MqSpacing.gapSm,
                  Icon(Icons.payment_rounded, size: 11, color: m.ink3),
                  MqSpacing.gapXxs,
                  Text(_paymentMethodLabel(method), style: context.text.labelSmall),
                ],
              ]),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(notes, style: context.text.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _discountTile(BuildContext context, Map<String, dynamic> d) {
    final m = context.mq;
    final amount = _toDouble(d['amount']);
    final createdAt = _formatDate(d['created_at']);
    final notes = (d['notes'] ?? '').toString();

    return MqSurface(
      tone: MqSurfaceTone.orange,
      padding: const EdgeInsets.all(MqSpacing.sm),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: m.orange.withValues(alpha: 0.16), borderRadius: MqRadius.brMd),
          child: Icon(Icons.local_offer_outlined, color: m.orange, size: MqSize.iconSm),
        ),
        MqSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_money2(amount), style: context.text.titleSmall),
              if (createdAt.isNotEmpty)
                Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 11, color: m.ink3),
                  MqSpacing.gapXxs,
                  Text(createdAt, style: context.text.labelSmall),
                ]),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(notes, style: context.text.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ]),
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
      children: [block(140), MqSpacing.gapMd, block(110), MqSpacing.gapMd, block(120)],
    );
  }
}
