import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
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
  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic>?
  _totals; // { total_paid, total_discount, total_remaining }
  final _currency = NumberFormat.currency(symbol: 'IQD ', decimalDigits: 0);
  int _touchedIndex = -1;

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  String _formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('yyyy-MM-dd').format(dt);
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
    setState(() => _loading = true);
    try {
      final data = await _api.fetchStudentInvoiceFull(widget.invoiceId);
      final invoice = Map<String, dynamic>.from(data['invoice'] ?? {});
      final payments = List<Map<String, dynamic>>.from(
        (data['payments'] ?? []) as List,
      );
      final totalsMap = data['totals'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['totals'])
          : null;

      setState(() {
        _invoice = invoice;
        _payments = payments;
        _totals = totalsMap;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // No longer needed: we read payments directly from API

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inv = _invoice;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: const GlobalAppBar(title: 'تفاصيل الفاتورة'),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            )
          : (inv == null)
          ? const Center(child: Text('تعذر تحميل الفاتورة'))
          : RefreshIndicator(
              onRefresh: _load,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(inv),
                      const SizedBox(height: 10),
                      _totalsPieChart(),
                      const SizedBox(height: 10),
                      _paymentsCard(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _load,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('تحديث', style: TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _header(Map<String, dynamic> inv) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = (inv['invoice_status'] ?? inv['status'] ?? '').toString();
    final due = _toDouble(inv['amount_due']);
    final invoiceDate = _formatDate(inv['invoice_date'] ?? inv['created_at']);
    final dueDate = _formatDate(inv['due_date']);
    final invoiceType = (inv['invoice_type'] ?? '').toString();
    final paymentMode = (inv['payment_mode'] ?? '').toString();
    final courseName = (inv['course_name'] ?? '').toString();
    final teacherName = (inv['teacher_name'] ?? '').toString();
    final notes = (inv['notes'] ?? '').toString();

    Color statusColor() {
      switch (status) {
        case 'paid':
          return AppColors.success;
        case 'partial':
          return AppColors.info;
        case 'overdue':
          return AppColors.error;
        default:
          return AppColors.warning;
      }
    }

    return Card(
      elevation: 1,
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.border,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor().withValues(alpha: .12),
                  child: Icon(
                    Icons.receipt_long,
                    color: statusColor(),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'قيمة الفاتورة: ${_currency.format(due)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'التاريخ: $invoiceDate',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor().withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: statusColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (courseName.isNotEmpty || teacherName.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (courseName.isNotEmpty)
                _infoRow(Icons.book, 'الكورس', courseName),
              if (teacherName.isNotEmpty)
                _infoRow(Icons.person, 'المعلم', teacherName),
            ],
            if (invoiceType.isNotEmpty || paymentMode.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (paymentMode.isNotEmpty)
                    Expanded(
                      child: _infoRow(
                        Icons.payment,
                        'طريقة الدفع',
                        _paymentModeLabel(paymentMode),
                      ),
                    ),
                ],
              ),
            ],
            if (dueDate.isNotEmpty) ...[
              const SizedBox(height: 6),
              _infoRow(Icons.event, 'تاريخ الاستحقاق', dueDate),
            ],
            const SizedBox(height: 10),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.note,
                      size: 14,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        notes,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const SizedBox(width: 8);

  Widget _kv(String k, String v, IconData ic, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: .1),
          child: Icon(ic, color: color, size: 16),
        ),
        const SizedBox(height: 6),
        Text(
          k,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          v,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _totalsPieChart() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _totals;
    if (t == null) return const SizedBox.shrink();
    final totalPaid = _toDouble(t['total_paid']);
    final totalDisc = _toDouble(t['total_discount']);
    final totalRemain = _toDouble(t['total_remaining']);
    final sum = totalPaid + totalDisc + totalRemain;
    if (sum <= 0) return const SizedBox.shrink();

    // Build slices list in order: Paid, Discount, Remaining
    final List<Map<String, dynamic>> items = [];
    if (totalPaid > 0) {
      items.add({
        'label': 'مدفوع',
        'value': totalPaid,
        'color': AppColors.success,
      });
    }
    if (totalDisc > 0) {
      items.add({
        'label': 'خصم',
        'value': totalDisc,
        'color': AppColors.warning,
      });
    }
    if (totalRemain > 0) {
      items.add({
        'label': 'متبقي',
        'value': totalRemain,
        'color': AppColors.error,
      });
    }

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final value = (it['value'] as double);
      final color = (it['color'] as Color);
      final percent = sum == 0 ? 0 : (value / sum) * 100;
      final isTouched = i == _touchedIndex;
      final title = '${percent.toStringAsFixed(0)}%';
      sections.add(
        PieChartSectionData(
          value: value,
          color: color,
          title: title,
          radius: isTouched ? 40 : 40,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.border,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'توزيع الإجمالي (مدفوع/خصم/متبقي)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 3,
                  centerSpaceRadius: 30,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!mounted) return;
                      final idx =
                          response?.touchedSection?.touchedSectionIndex ?? -1;
                      setState(() {
                        _touchedIndex = event.isInterestedForInteractions
                            ? idx
                            : -1;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            if (_touchedIndex >= 0 && _touchedIndex < items.length) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (_) {
                  final sel = items[_touchedIndex];
                  final val = (sel['value'] as double);
                  final pct = sum == 0 ? 0 : (val / sum) * 100;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.border,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: sel['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${sel['label']}: ${_currency.format(val)} (${pct.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: const [
                _Legend(color: AppColors.success, text: 'مدفوع'),
                _Legend(color: AppColors.warning, text: 'خصم'),
                _Legend(color: AppColors.error, text: 'متبقي'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentsCard() {
    if (_payments.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 1,
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.border,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'جدول الدفعات',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ..._payments.map((p) => _paymentTile(p)),
          ],
        ),
      ),
    );
  }

  Widget _paymentTile(Map<String, dynamic> p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payNo = (p['payment_number'] ?? '').toString();
    final planned = _toDouble(p['planned_amount']);
    final paid = _toDouble(p['paid_amount']);
    final disc = _toDouble(p['discount_amount']);
    final remain = _toDouble(p['remaining_amount']);
    final status = (p['status'] ?? '').toString();
    final dueDate = _formatDate(p['due_date']);
    final paidDate = _formatDate(p['paid_date']);
    final notes = (p['notes'] ?? '').toString();
    final instId = (p['installment_id'] ?? '').toString();

    Color statusColor() {
      switch (status) {
        case 'paid':
          return AppColors.success;
        case 'partial':
          return AppColors.info;
        case 'overdue':
          return AppColors.error;
        default:
          return AppColors.warning;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor().withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'قسط ${payNo.isNotEmpty ? payNo : '-'}',
                  style: TextStyle(
                    color: statusColor(),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (dueDate.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dueDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              if (paidDate.isNotEmpty) ...[
                const SizedBox(width: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      paidDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _kv(
                  'المخطط',
                  _currency.format(planned),
                  Icons.stacked_bar_chart,
                  AppColors.primary,
                ),
              ),
              _divider(),
              Expanded(
                child: _kv(
                  'المدفوع',
                  _currency.format(paid),
                  Icons.payments,
                  AppColors.success,
                ),
              ),
              _divider(),
              Expanded(
                child: _kv(
                  'الخصم',
                  _currency.format(disc),
                  Icons.local_offer,
                  AppColors.warning,
                ),
              ),
              _divider(),
              Expanded(
                child: _kv(
                  'المتبقي',
                  _currency.format(remain),
                  Icons.account_balance_wallet,
                  AppColors.error,
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              notes,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: instId.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => InstallmentDetailsScreen(
                            invoiceId: widget.invoiceId,
                            installmentId: instId,
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text(
                'عرض المزيد',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوعة';
      case 'partial':
        return 'سداد جزئي';
      case 'overdue':
        return 'متأخرة';
      default:
        return 'قيد السداد';
    }
  }

  String _paymentModeLabel(String mode) {
    switch (mode) {
      case 'installments':
        return 'أقساط';
      case 'full':
        return 'دفعة واحدة';
      default:
        return mode;
    }
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
