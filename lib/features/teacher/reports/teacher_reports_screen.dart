import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_bottom_nav.dart';
import '../shared/teacher_helpers.dart';

/// Teacher → "التقارير المالية" (financial.vue).
class TeacherReportsScreen extends StatefulWidget {
  const TeacherReportsScreen({super.key});
  @override
  State<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> {
  final _api = TeacherApiService();
  bool _loading = false;
  Map<String, dynamic> _report = const {};
  String? _studyYear;
  List<String> _years = [];

  @override
  void initState() { super.initState(); _bootstrap(); }

  Future<void> _bootstrap() async {
    try {
      final res = await _api.fetchAcademicYears();
      final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
      final years = (data['years'] is List) ? (data['years'] as List) : [];
      _years = years.map((y) => (y is Map ? (y['year']?.toString() ?? '') : y.toString())).where((s) => s.isNotEmpty).cast<String>().toList();
      _studyYear = (data['active'] is Map) ? data['active']['year']?.toString() : (_years.isNotEmpty ? _years.first : null);
    } catch (_) {}
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchFinancialReport(studyYear: _studyYear);
      _report = (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب التقرير', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoices = (_report['invoices'] is Map) ? Map<String, dynamic>.from(_report['invoices']) : <String, dynamic>{};
    final student = (invoices['student'] is Map) ? Map<String, dynamic>.from(invoices['student']) : <String, dynamic>{};
    final reservation = (invoices['reservation'] is Map) ? Map<String, dynamic>.from(invoices['reservation']) : <String, dynamic>{};
    final expenses = (_report['expenses'] is Map) ? Map<String, dynamic>.from(_report['expenses']) : <String, dynamic>{};
    final summary = (_report['summary'] is Map) ? Map<String, dynamic>.from(_report['summary']) : <String, dynamic>{};

    final paidIncome = num.tryParse((summary['totalPaidIncome'] ?? 0).toString()) ?? 0;
    final dueIncome = num.tryParse((summary['totalDueIncome'] ?? 0).toString()) ?? 0;
    final exp = num.tryParse((expenses['total'] ?? 0).toString()) ?? 0;
    final netPaid = num.tryParse((summary['netProfitPaidBasis'] ?? 0).toString()) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير المالية'),
          actions: [IconButton(onPressed: _loading ? null : _fetch, icon: const Icon(Icons.refresh))]),
      drawer: const TeacherDrawer(),
      bottomNavigationBar: const TeacherBottomNav(),
      body: RefreshIndicator(onRefresh: _fetch, child: ListView(padding: const EdgeInsets.all(16), children: [
        TeacherHero(title: 'التقرير المالي', subtitle: 'السنة: ${_studyYear ?? '—'}', icon: Icons.bar_chart_outlined,
            trailing: _years.length > 1 ? PopupMenuButton<String>(
              initialValue: _studyYear,
              onSelected: (v) async { setState(() => _studyYear = v); await _fetch(); },
              itemBuilder: (ctx) => _years.map((y) => PopupMenuItem(value: y, child: Text(y))).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.expand_more, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('السنة', style: TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            ) : null),
        const SizedBox(height: 16),

        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.15, children: [
          KpiTile(title: 'الدخل المقبوض', value: fmtIQDShort(paidIncome), subtitle: 'مدفوع فعلياً',
              icon: Icons.payments_outlined, color: Colors.green),
          KpiTile(title: 'الدخل المستحق', value: fmtIQDShort(dueIncome), subtitle: 'إجمالي محقق',
              icon: Icons.account_balance_outlined, color: kSky),
          KpiTile(title: 'المصاريف', value: fmtIQDShort(exp), subtitle: 'إجمالي',
              icon: Icons.shopping_cart_outlined, color: Colors.red),
          KpiTile(title: 'صافي الربح', value: fmtIQDShort(netPaid), subtitle: 'مقبوض - مصاريف',
              icon: Icons.trending_up, color: netPaid >= 0 ? Colors.green : Colors.red),
        ]),
        const SizedBox(height: 16),

        _Section(title: 'فواتير الطلاب', icon: Icons.receipt_long_outlined, color: kSky, data: student),
        const SizedBox(height: 10),
        _Section(title: 'فواتير العربون', icon: Icons.savings_outlined, color: kOrange, data: reservation),
      ])),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.color, required this.data});
  final String title;
  final IconData icon;
  final Color color;
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14))]),
        const SizedBox(height: 10),
        _Row(label: 'المستحق', value: fmtIQD(data['totalDue']), color: cs.onSurface),
        _Row(label: 'الخصومات', value: fmtIQD(data['totalDiscount']), color: kOrange),
        _Row(label: 'المدفوع', value: fmtIQD(data['totalPaid']), color: Colors.green),
        _Row(label: 'المتبقّي', value: fmtIQD(data['totalRemaining']), color: Colors.red),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }
}
