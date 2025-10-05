import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InstallmentDetailsScreen extends StatefulWidget {
  final String invoiceId;
  final String installmentId;
  const InstallmentDetailsScreen({
    super.key,
    required this.invoiceId,
    required this.installmentId,
  });

  @override
  State<InstallmentDetailsScreen> createState() =>
      _InstallmentDetailsScreenState();
}

class _InstallmentDetailsScreenState extends State<InstallmentDetailsScreen> {
  final _api = ApiService();
  bool _loading = true;

  Map<String, dynamic>? _invoice;
  Map<String, dynamic>? _installment;
  List<Map<String, dynamic>> _partials = [];
  List<Map<String, dynamic>> _discounts = [];
  Map<String, dynamic>?
  _totals; // { total_planned, total_paid, total_discount, total_remaining }

  final _currency = NumberFormat.currency(symbol: 'IQD ', decimalDigits: 0);
  final _dateFmt = DateFormat('yyyy-MM-dd');

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  String _formatDate(dynamic v) {
    if (v == null || v.toString().isEmpty) return '';
    try {
      final dt = DateTime.parse(v.toString());
      return _dateFmt.format(dt);
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
    setState(() => _loading = true);
    try {
      final data = await _api.fetchStudentInstallmentFull(
        invoiceId: widget.invoiceId,
        installmentId: widget.installmentId,
      );
      setState(() {
        _invoice = data['invoice'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['invoice'])
            : null;
        _installment = data['installment'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['installment'])
            : null;
        _partials = List<Map<String, dynamic>>.from(
          (data['partials'] ?? []) as List,
        );
        _discounts = List<Map<String, dynamic>>.from(
          (data['discounts'] ?? []) as List,
        );
        _totals = data['totals'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['totals'])
            : null;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: const GlobalAppBar(title: 'تفاصيل القسط'),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            )
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
                      _header(),
                      const SizedBox(height: 10),
                      _totalsPie(),
                      const SizedBox(height: 10),
                      if (_partials.isNotEmpty) _partialsCard(),
                      if (_discounts.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _discountsCard(),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _header() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inv = _invoice ?? const {};
    final ins = _installment ?? const {};
    final courseName = (inv['course_name'] ?? '').toString();
    final teacherName = (inv['teacher_name'] ?? '').toString();
    final number = ins['payment_number']?.toString() ?? '-';
    final status = (ins['status'] ?? '').toString();
    final planned = _toDouble(ins['planned_amount']);
    final paid = _toDouble(ins['paid_amount']);
    final remain = _toDouble(ins['remaining_amount']);
    final dueDate = _formatDate(ins['due_date']);
    final paidDate = _formatDate(ins['paid_date']);

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
                  child: Icon(Icons.payments, color: statusColor(), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'قسط $number',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (courseName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'الكورس: $courseName',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (teacherName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'المعلم: $teacherName',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
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
                    'المتبقي',
                    _currency.format(remain),
                    Icons.account_balance_wallet,
                    AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (dueDate.isNotEmpty) ...[
                  Icon(
                    Icons.event,
                    size: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'الاستحقاق: $dueDate',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
                if (paidDate.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'الدفع: $paidDate',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalsPie() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _totals;
    if (t == null) return const SizedBox.shrink();
    final totalPlanned = _toDouble(t['total_planned']);
    final totalPaid = _toDouble(t['total_paid']);
    final totalDisc = _toDouble(t['total_discount']);
    final totalRemain = _toDouble(t['total_remaining']);
    final sum = totalPlanned + totalPaid + totalDisc + totalRemain;
    if (sum <= 0) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[
      if (totalPaid > 0)
        PieChartSectionData(
          value: totalPaid,
          color: AppColors.success,
          title: '${((totalPaid / sum) * 100).toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      if (totalDisc > 0)
        PieChartSectionData(
          value: totalDisc,
          color: AppColors.warning,
          title: '${((totalDisc / sum) * 100).toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      if (totalRemain > 0)
        PieChartSectionData(
          value: totalRemain,
          color: AppColors.error,
          title: '${((totalRemain / sum) * 100).toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
    ];

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
              'توزيع القسط (مدفوع/خصم/متبقي)',
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
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
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

  Widget _partialsCard() {
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
              'دفعات جزئية',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ..._partials.map((p) => _partialTile(p)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _discountsCard() {
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
              'الخصومات',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ..._discounts.map((d) => _discountTile(d)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _partialTile(Map<String, dynamic> p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amount = _toDouble(p['amount']);
    final paidAt = _formatDate(p['paid_at']);
    final method = (p['payment_method'] ?? '').toString();
    final notes = (p['notes'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.success.withValues(alpha: .12),
            child: Icon(Icons.payments, color: AppColors.success, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currency.format(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (paidAt.isNotEmpty) ...[
                      Icon(
                        Icons.calendar_today,
                        size: 10,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        paidAt,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (method.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.payment,
                        size: 10,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _paymentMethodLabel(method),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _discountTile(Map<String, dynamic> d) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amount = _toDouble(d['amount']);
    final createdAt = _formatDate(d['created_at']);
    final notes = (d['notes'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.warning.withValues(alpha: .12),
            child: Icon(Icons.local_offer, color: AppColors.warning, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currency.format(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (createdAt.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 10,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        createdAt,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوع';
      case 'partial':
        return 'سداد جزئي';
      case 'overdue':
        return 'متأخر';
      default:
        return 'قيد السداد';
    }
  }

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
            fontSize: 10,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
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

  Widget _divider() => const SizedBox(width: 8);

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'نقدي';
      case 'card':
        return 'بطاقة';
      case 'transfer':
        return 'تحويل';
      default:
        return method;
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
