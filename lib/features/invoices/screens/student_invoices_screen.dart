import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class StudentInvoicesScreen extends StatefulWidget {
  const StudentInvoicesScreen({super.key});

  @override
  State<StudentInvoicesScreen> createState() => _StudentInvoicesScreenState();
}

class _StudentInvoicesScreenState extends State<StudentInvoicesScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _studyYear;
  String? _courseId;
  String? _status;
  final _currency = NumberFormat.currency(symbol: 'IQD ', decimalDigits: 0);
  final _dateFormat = DateFormat('yyyy-MM-dd');

  List<Map<String, dynamic>> _invoices = [];
  int _total = 0;
  double? _rTotalDue;
  double? _rTotalDisc;
  double? _rTotalPaid;
  double? _rTotalRemain;

  String _currentStudyYear() {
    final now = DateTime.now();
    final startYear = now.month >= 9 ? now.year : now.year - 1;
    final endYear = startYear + 1;
    return '$startYear-$endYear';
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
    setState(() => _loading = true);
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
      double? rDue;
      double? rDisc;
      double? rPaid;
      double? rRemain;

      if (data is Map<String, dynamic>) {
        // New shape: { invoices: [...], report: {...} }
        final list =
            (data['invoices'] ?? data['items'] ?? data['data'] ?? []) as List;
        items = List<Map<String, dynamic>>.from(list);
        _total = items.length;

        final report = data['report'];
        if (report is Map<String, dynamic>) {
          double parseNum(dynamic v) {
            if (v is num) return v.toDouble();
            if (v is String) return double.tryParse(v) ?? 0;
            return 0;
          }

          rDue = parseNum(report['total_amount_due']);
          rDisc = parseNum(report['total_discount']);
          rPaid = parseNum(report['total_paid']);
          rRemain = parseNum(report['total_remaining']);
        }
      } else if (data is List) {
        // Fallback legacy shape
        items = List<Map<String, dynamic>>.from(data);
        _total = items.length;
      } else {
        items = [];
        _total = 0;
      }

      setState(() {
        _invoices = items;
        _rTotalDue = rDue;
        _rTotalDisc = rDisc;
        _rTotalPaid = rPaid;
        _rTotalRemain = rRemain;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, double> _aggregatePaidStatus() {
    double paid = 0;
    double unpaid = 0;

    for (final inv in _invoices) {
      final st = (inv['invoice_status'] ?? inv['status'] ?? 'pending')
          .toString();
      if (st == 'paid') {
        paid += 1;
      } else {
        unpaid += 1;
      }
    }

    return {"paid": paid, "unpaid": unpaid};
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

  String _formatDate(dynamic dateValue) {
    if (dateValue == null || dateValue.toString().isEmpty) return 'غير محدد';
    try {
      final date = DateTime.parse(dateValue.toString());
      return _dateFormat.format(date);
    } catch (e) {
      return dateValue.toString().split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paidStatus = _aggregatePaidStatus();
    final totalDue = _rTotalDue ?? _sumField('amount_due');
    final totalDisc = _rTotalDisc ?? _sumField('discount_total');
    final totalPaid = _rTotalPaid ?? _sumField('amount_paid');
    final totalRemain = _rTotalRemain ?? _sumField('remaining_amount');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GlobalAppBar(title: 'فواتيري ودفعاتي'),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _filters(),
                const SizedBox(height: 10),
                _summaryCards(
                  totalDue: totalDue,
                  totalDisc: totalDisc,
                  totalPaid: totalPaid,
                  totalRemain: totalRemain,
                ),
                const SizedBox(height: 10),
                _chartsSection(paidStatus),
                const SizedBox(height: 10),
                _loading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : _invoices.isEmpty
                    ? _empty()
                    : _list(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _load,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text(
          'تحديث',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        elevation: 3,
      ),
    );
  }

  Widget _filters() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: AppColors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'تصفية الفواتير',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: _status ?? 'all',
                      decoration: InputDecoration(
                        labelText: 'الحالة',
                        labelStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            'الكل',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text(
                            'قيد السداد',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'partial',
                          child: Text(
                            'سداد جزئي',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'paid',
                          child: Text(
                            'مدفوعة',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'overdue',
                          child: Text(
                            'متأخرة',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _status = (v == 'all') ? null : v;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _studyYear ?? _currentStudyYear(),
                    decoration: InputDecoration(
                      labelText: 'السنة الدراسية',
                      labelStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: _currentStudyYear(),
                        child: Text(
                          _currentStudyYear(),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _studyYear = val;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text(
                  'تصفية',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards({
    required double totalDue,
    required double totalDisc,
    required double totalPaid,
    required double totalRemain,
  }) {
    Widget card(
      IconData icon,
      String title,
      double value,
      Color color,
      Color bgColor,
    ) {
      return Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _currency.format(value),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        card(
          Icons.receipt_long_rounded,
          'إجمالي الفواتير',
          totalDue,
          AppColors.primary,
          AppColors.primary.withValues(alpha: 0.1),
        ),
        card(
          Icons.local_offer_rounded,
          'الخصومات',
          totalDisc,
          AppColors.warning,
          AppColors.warning.withValues(alpha: 0.1),
        ),
        card(
          Icons.payments_rounded,
          'المدفوع',
          totalPaid,
          AppColors.success,
          AppColors.success.withValues(alpha: 0.1),
        ),
        card(
          Icons.account_balance_wallet_rounded,
          'المتبقي',
          totalRemain,
          AppColors.error,
          AppColors.error.withValues(alpha: 0.1),
        ),
      ],
    );
  }

  Widget _chartsSection(Map<String, double> paidStatus) {
    final total = paidStatus.values.fold<double>(0, (p, e) => p + e);
    if (total == 0) return const SizedBox.shrink();

    final paidCount = paidStatus['paid'] ?? 0;
    final unpaidCount = paidStatus['unpaid'] ?? 0;
    final paidPercent = ((paidCount / total) * 100).toStringAsFixed(1);
    final unpaidPercent = ((unpaidCount / total) * 100).toStringAsFixed(1);

    final pieSections = <PieChartSectionData>[
      if (paidCount > 0)
        PieChartSectionData(
          value: paidCount,
          color: AppColors.success,
          title: '$paidPercent%',
          radius: 55,
          titleStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      if (unpaidCount > 0)
        PieChartSectionData(
          value: unpaidCount,
          color: AppColors.error,
          title: '$unpaidPercent%',
          radius: 55,
          titleStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.pie_chart_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'توزيع الفواتير (مسدد / غير مسدد)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 140,
                    child: PieChart(
                      PieChartData(
                        sections: pieSections,
                        sectionsSpace: 3,
                        centerSpaceRadius: 30,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItemWithCount(
                      'مسدد',
                      AppColors.success,
                      paidCount.toInt(),
                    ),
                    const SizedBox(height: 8),
                    _legendItemWithCount(
                      'غير مسدد',
                      AppColors.error,
                      unpaidCount.toInt(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItemWithCount(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _list() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'الفواتير ($_total)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _load,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: Text(
                  'تحديث',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ..._invoices.map((inv) => _invoiceTile(inv)),
        const SizedBox(height: 70),
      ],
    );
  }

  Widget _invoiceTile(Map<String, dynamic> inv) {
    final status = (inv['invoice_status'] ?? inv['status'] ?? '').toString();
    final due = _toDouble(inv['amount_due']);
    final paid = _toDouble(inv['amount_paid']);
    final remain = _toDouble(inv['remaining_amount']);
    final discount = _toDouble(inv['discount_total']);
    final invoiceDate = _formatDate(
      inv['invoice_date'] ?? inv['created_at'] ?? inv['createdAt'],
    );
    final dueDate = _formatDate(inv['due_date'] ?? inv['dueDate']);
    final notes = inv['notes']?.toString() ?? '';
    final courseName = inv['course_name']?.toString() ?? '';
    final teacherName = inv['teacher_name']?.toString() ?? '';

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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor().withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor().withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final id = inv['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              Get.toNamed('/invoice-details', arguments: id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: statusColor(),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (courseName.isNotEmpty ||
                              teacherName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            if (courseName.isNotEmpty)
                              Row(
                                children: [
                                  Icon(
                                    Icons.book_rounded,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      courseName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            if (teacherName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      teacherName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 2),
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
                        color: statusColor().withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          color: statusColor(),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _detailRow(
                        'المبلغ المستحق',
                        _currency.format(due),
                        AppColors.textPrimary,
                        true,
                      ),
                      const SizedBox(height: 6),
                      _detailRow(
                        'الخصم',
                        _currency.format(discount),
                        AppColors.warning,
                        false,
                      ),
                      const SizedBox(height: 6),
                      _detailRow(
                        'المدفوع',
                        _currency.format(paid),
                        AppColors.success,
                        false,
                      ),
                      const SizedBox(height: 6),
                      _detailRow(
                        'المتبقي',
                        _currency.format(remain),
                        AppColors.error,
                        true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 10,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'تاريخ الفاتورة: ',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            invoiceDate,
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_rounded,
                            size: 10,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'تاريخ الاستحقاق: ',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            dueDate,
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.note_rounded,
                          size: 12,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            notes,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'اضغط للمزيد من التفاصيل',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.primary,
                      size: 10,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color valueColor, bool bold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 12 : 11,
            color: valueColor,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
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

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد فواتير',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'لا توجد فواتير للعرض حالياً',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
