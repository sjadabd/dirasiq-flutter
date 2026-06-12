import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_helpers.dart'
    show fmtIQD, fmtIQDShort, fmtNum, initialsOf;
import 'widgets/teacher_invoice_form_sheet.dart';

/// Teacher → invoice details (عرض). Shows the invoice header + amounts and the
/// installment rows, and lets the teacher record a payment (تسديد) per
/// installment as the student pays. An "تعديل" action opens the full edit
/// sheet. Adding payment / discount lives HERE (inside the invoice), not on the
/// list card.
class TeacherInvoiceDetailScreen extends StatefulWidget {
  const TeacherInvoiceDetailScreen({
    super.key,
    required this.invoiceId,
    this.studentName,
    this.courseName,
  });
  final String invoiceId;

  /// Seed names from the list card so the header shows them immediately even
  /// before/if the detail endpoint doesn't echo them back.
  final String? studentName;
  final String? courseName;

  @override
  State<TeacherInvoiceDetailScreen> createState() =>
      _TeacherInvoiceDetailScreenState();
}

class _TeacherInvoiceDetailScreenState
    extends State<TeacherInvoiceDetailScreen> {
  final _api = TeacherApiService();

  bool _loading = true;
  bool _changed = false; // tell the list to refresh on pop
  Map<String, dynamic> _invoice = const {};
  List<Map<String, dynamic>> _installments = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchInvoiceFull(widget.invoiceId);
      final data = (res['data'] is Map)
          ? Map<String, dynamic>.from(res['data'])
          : <String, dynamic>{};
      _invoice = (data['invoice'] is Map)
          ? Map<String, dynamic>.from(data['invoice'])
          : {};
      final list = data['installments'];
      _installments = (list is List)
          ? list
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
          : [];
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب تفاصيل الفاتورة',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  num _n(dynamic v) => num.tryParse((v ?? 0).toString()) ?? 0;

  bool get _isInstallments =>
      (_invoice['payment_mode'] ?? '').toString() == 'installments';

  Future<void> _payInstallment(Map<String, dynamic> inst) async {
    final remaining = _n(inst['remaining_amount']);
    if (remaining <= 0) return;
    final ok = await _paymentDialog(
      title: 'تسديد القسط ${inst['installment_number']}',
      remaining: remaining,
      installmentId: inst['id'].toString(),
    );
    if (ok) {
      _changed = true;
      await _fetch();
    }
  }

  Future<void> _payCash() async {
    final remaining = _n(_invoice['remaining_amount']);
    if (remaining <= 0) return;
    final ok = await _paymentDialog(
      title: 'تسديد الفاتورة',
      remaining: remaining,
      installmentId: null,
    );
    if (ok) {
      _changed = true;
      await _fetch();
    }
  }

  /// Returns true if a payment was successfully recorded.
  Future<bool> _paymentDialog({
    required String title,
    required num remaining,
    required String? installmentId,
  }) async {
    final amountCtl = TextEditingController(text: fmtNum(remaining));
    String method = 'cash';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المتبقّي: ${fmtIQD(remaining)}',
                    style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'المبلغ المستلم',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                      labelText: 'طريقة الدفع',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقد')),
                    DropdownMenuItem(
                        value: 'bank_transfer', child: Text('تحويل بنكي')),
                    DropdownMenuItem(
                        value: 'credit_card', child: Text('بطاقة')),
                    DropdownMenuItem(
                        value: 'mobile_payment', child: Text('دفع جوال')),
                  ],
                  onChanged: (v) => setLocal(() => method = v ?? 'cash'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('تسديد')),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return false;
    final amount =
        num.tryParse(amountCtl.text.replaceAll(',', '').trim()) ?? 0;
    if (amount <= 0) return false;
    try {
      await _api.addInvoicePayment(widget.invoiceId, {
        'amount': amount,
        'paymentMethod': method,
        if (installmentId != null) 'installmentId': installmentId,
      });
      Get.snackbar('تم', 'تم تسجيل الدفعة وإشعار الطالب',
          snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر تسجيل الدفعة',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<void> _openEdit() async {
    final hasPayments = _n(_invoice['amount_paid']) > 0;
    if (hasPayments) {
      Get.snackbar('غير ممكن',
          'لا يمكن تعديل فاتورة بدأ تحصيل دفعات منها. استخدم التسديد.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => TeacherInvoiceFormSheet(
        api: _api,
        studyYear: (_invoice['study_year'] ?? '').toString(),
        existing: _invoice,
        existingInstallments: _installments,
      ),
    );
    if (saved == true) {
      _changed = true;
      Get.snackbar('تم', 'تم تعديل الفاتورة وإشعار الطالب',
          snackPosition: SnackPosition.BOTTOM);
      await _fetch();
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
          final hasPayments = _n(_invoice['amount_paid']) > 0;
          return Scaffold(
            backgroundColor: mq.page,
            appBar: TeacherAppBar(
              title: 'تفاصيل الفاتورة',
              actions: [
                if (!_loading && _invoice.isNotEmpty && !hasPayments)
                  IconButton(
                    tooltip: 'تعديل',
                    onPressed: _openEdit,
                    icon: Icon(Icons.edit_outlined, color: mq.ink2),
                  ),
              ],
            ),
            body: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                Navigator.of(context).pop(_changed);
              },
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _invoice.isEmpty
                      ? Center(
                          child: Text('لا توجد بيانات',
                              style: context.text.bodyMedium
                                  ?.copyWith(color: mq.ink2)))
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          color: mq.accent,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(MqSpacing.lg,
                                MqSpacing.lg, MqSpacing.lg, MqSpacing.xxl),
                            children: [
                              _headerCard(context),
                              const SizedBox(height: MqSpacing.md),
                              _amountsCard(context),
                              const SizedBox(height: MqSpacing.lg),
                              if (_isInstallments)
                                _installmentsCard(context)
                              else
                                _cashCard(context),
                            ],
                          ),
                        ),
            ),
          );
        }),
      ),
    );
  }

  Widget _headerCard(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final status = (_invoice['invoice_status'] ?? '').toString();
    final (label, tone) = _statusMeta(status);
    final studentName =
        (_invoice['student_name'] ?? widget.studentName ?? '—').toString();
    final courseName =
        (_invoice['course_name'] ?? widget.courseName ?? '—').toString();
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: t.infoSoft,
                shape: BoxShape.circle,
                border: Border.all(color: t.infoLine)),
            alignment: Alignment.center,
            child: Text(initialsOf(studentName),
                style: MqTypography.mono(
                    color: t.info, size: 15, weight: FontWeight.w700)),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: mq.ink2)),
              ],
            ),
          ),
          const SizedBox(width: MqSpacing.sm),
          TeacherStatusPill(label: label, tone: tone),
        ],
      ),
    );
  }

  Widget _amountsCard(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Column(
        children: [
          _amountRow(context, 'المبلغ المستحق', fmtIQD(_invoice['amount_due']),
              mq.ink),
          _amountRow(context, 'الخصم', fmtIQD(_invoice['discount_total']),
              mq.ink2),
          _amountRow(
              context, 'المدفوع', fmtIQD(_invoice['amount_paid']), t.success),
          Divider(height: MqSpacing.lg, color: mq.line),
          _amountRow(context, 'المتبقّي',
              fmtIQD(_invoice['remaining_amount']), t.danger,
              bold: true),
        ],
      ),
    );
  }

  Widget _amountRow(
      BuildContext context, String label, String value, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: context.text.bodyMedium
                    ?.copyWith(color: context.mq.ink2)),
          ),
          Text(value,
              style: MqTypography.mono(
                  color: color,
                  size: bold ? 15 : 14,
                  weight: bold ? FontWeight.w800 : FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _installmentsCard(BuildContext context) {
    final mq = context.mq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.list_alt_outlined, size: 18, color: mq.ink3),
          const SizedBox(width: MqSpacing.sm),
          Text('الأقساط (${_installments.length})',
              style: context.text.titleSmall),
        ]),
        const SizedBox(height: MqSpacing.sm),
        if (_installments.isEmpty)
          Text('لا توجد أقساط',
              style: context.text.bodySmall?.copyWith(color: mq.ink3))
        else
          ..._installments.map((inst) => Padding(
                padding: const EdgeInsets.only(bottom: MqSpacing.sm),
                child: _InstallmentTile(
                  inst: inst,
                  onPay: () => _payInstallment(inst),
                ),
              )),
      ],
    );
  }

  Widget _cashCard(BuildContext context) {
    final mq = context.mq;
    final remaining = _n(_invoice['remaining_amount']);
    final paid = remaining <= 0;
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(
        children: [
          Icon(paid ? Icons.check_circle_outline : Icons.payments_outlined,
              color: paid ? context.teacher.success : mq.ink3),
          const SizedBox(width: MqSpacing.sm),
          Expanded(
            child: Text(paid ? 'فاتورة كاش مدفوعة بالكامل' : 'فاتورة كاش',
                style: context.text.bodyMedium),
          ),
          if (!paid)
            MqButton.secondary(
              label: 'تسديد',
              icon: Icons.add_rounded,
              size: MqButtonSize.small,
              expand: false,
              onPressed: _payCash,
            ),
        ],
      ),
    );
  }

  static (String, TeacherTone) _statusMeta(String s) {
    switch (s) {
      case 'paid':
        return ('مدفوعة', TeacherTone.success);
      case 'partial':
        return ('جزئية', TeacherTone.info);
      case 'pending':
        return ('معلّقة', TeacherTone.warning);
      case 'overdue':
        return ('متأخرة', TeacherTone.danger);
      case 'cancelled':
        return ('ملغاة', TeacherTone.neutral);
      default:
        return ('—', TeacherTone.neutral);
    }
  }
}

class _InstallmentTile extends StatelessWidget {
  const _InstallmentTile({required this.inst, required this.onPay});
  final Map<String, dynamic> inst;
  final VoidCallback onPay;

  num _n(dynamic v) => num.tryParse((v ?? 0).toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final t = context.teacher;
    final status = (inst['installment_status'] ?? '').toString();
    final isPaid = status == 'paid';
    final remaining = _n(inst['remaining_amount']);
    final (base, soft, line) = switch (status) {
      'paid' => (t.success, t.successSoft, t.successLine),
      'partial' => (t.info, t.infoSoft, t.infoLine),
      'overdue' => (t.danger, t.dangerSoft, t.dangerLine),
      _ => (t.warning, t.warningSoft, t.warningLine),
    };
    return Container(
      padding: const EdgeInsets.all(MqSpacing.md),
      decoration: BoxDecoration(
        color: mq.card,
        borderRadius: MqRadius.brMd,
        border: Border.all(color: mq.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: soft, shape: BoxShape.circle, border: Border.all(color: line)),
            child: Text('${inst['installment_number']}',
                style: MqTypography.mono(
                    color: base, size: 13, weight: FontWeight.w700)),
          ),
          const SizedBox(width: MqSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(fmtIQDShort(inst['planned_amount']),
                        style: MqTypography.mono(
                            color: mq.ink, size: 14, weight: FontWeight.w700)),
                    const SizedBox(width: MqSpacing.sm),
                    if (_n(inst['paid_amount']) > 0 && !isPaid)
                      Text('مدفوع ${fmtIQDShort(inst['paid_amount'])}',
                          style: context.text.labelSmall
                              ?.copyWith(color: t.success)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('الاستحقاق: ${inst['due_date'] ?? '—'}',
                    style: context.text.labelSmall?.copyWith(color: mq.ink3)),
              ],
            ),
          ),
          const SizedBox(width: MqSpacing.sm),
          if (isPaid)
            Icon(Icons.check_circle, color: t.success, size: 24)
          else
            MqButton.secondary(
              label: 'تسديد',
              size: MqButtonSize.small,
              expand: false,
              onPressed: remaining <= 0 ? null : onPay,
            ),
        ],
      ),
    );
  }
}
