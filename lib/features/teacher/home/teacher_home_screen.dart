import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_bottom_nav.dart';

/// Teacher home — mirrors the dashboard's [dashboard.vue]:
///   • Hero greeting strip with the teacher's name + today's date.
///   • 4 KPI cards: students / courses / today's sessions / received deposits.
///   • Two financial summary cards: deposit invoices + student invoices.
///   • Pull-to-refresh.
class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  final TeacherApiService _api = TeacherApiService();
  bool _loading = false;
  Map<String, dynamic>? _kpis;
  String _teacherName = '';

  @override
  void initState() {
    super.initState();
    _loadName();
    _fetch();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw == null) return;
    try {
      final user = jsonDecode(raw) as Map<String, dynamic>;
      setState(() => _teacherName = (user['name'] ?? '').toString());
    } catch (_) {}
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchDashboardOverview();
      final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : <String, dynamic>{};
      if (mounted) setState(() => _kpis = data);
    } catch (e) {
      if (mounted) {
        Get.snackbar('خطأ', 'تعذّر جلب بيانات اللوحة', snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(dynamic n) {
    if (n == null) return '0';
    final v = (n is num) ? n : num.tryParse(n.toString());
    if (v == null) return '0';
    return v.toInt().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  String _todayArabic() {
    final d = DateTime.now();
    const months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final k = _kpis ?? {};
    final deposit = (k['depositInvoices'] is Map) ? Map<String, dynamic>.from(k['depositInvoices']) : {};
    final student = (k['studentInvoices'] is Map) ? Map<String, dynamic>.from(k['studentInvoices']) : {};

    return Scaffold(
      appBar: const TeacherAppBar(title: 'الرئيسية'),
      drawer: const TeacherDrawer(),
      bottomNavigationBar: const TeacherBottomNav(),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Hero greeting
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B2545), Color(0xFF163E72)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFFF8A00),
                    child: Text(
                      _teacherName.isNotEmpty ? _teacherName.characters.first : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أهلاً، ${_teacherName.isEmpty ? 'أستاذ' : _teacherName}',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _todayArabic(),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4 KPI cards (2x2 grid). Aspect ratio tuned so the icon row +
            // value + 2-line subtitle fit without overflow on small phones.
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _KpiCard(
                  title: 'إجمالي الطلاب',
                  value: _fmt(k['totalStudents']),
                  subtitle: 'النشطون: ${_fmt(k['activeStudents'])}',
                  icon: Icons.group_outlined,
                  color: cs.primary,
                ),
                _KpiCard(
                  title: 'الكورسات',
                  value: _fmt(k['totalCourses']),
                  subtitle: 'النشطة: ${_fmt(k['activeCourses'])}',
                  icon: Icons.book_outlined,
                  color: Colors.teal,
                ),
                _KpiCard(
                  title: 'جلسات اليوم',
                  value: _fmt(k['sessionsToday']),
                  subtitle: 'مجدولة',
                  icon: Icons.event_outlined,
                  color: const Color(0xFFFF8A00),
                ),
                _KpiCard(
                  title: 'العربون المُستلَم',
                  value: _fmt(k['receivedDeposit']),
                  subtitle: 'متبقّي: ${_fmt(k['remainingDeposit'])}',
                  icon: Icons.payments_outlined,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Deposit invoices summary
            _SummaryCard(
              title: 'فواتير العربون',
              icon: Icons.shopping_bag_outlined,
              color: const Color(0xFFFF8A00),
              rows: [
                _SummaryRow('المستحق',  _fmt(deposit['totalAmount']),    color: cs.onSurface),
                _SummaryRow('المدفوع',  _fmt(deposit['receivedAmount']), color: Colors.green),
                _SummaryRow('المتبقّي', _fmt(deposit['remainingAmount']), color: Colors.red),
              ],
            ),
            const SizedBox(height: 12),

            // Student invoices summary
            _SummaryCard(
              title: 'فواتير الطلاب',
              icon: Icons.receipt_long_outlined,
              color: cs.primary,
              rows: [
                _SummaryRow('المستحق',  _fmt(student['totalDue']),       color: cs.onSurface),
                _SummaryRow('المدفوع',  _fmt(student['amountPaid']),     color: Colors.green),
                _SummaryRow('المتبقّي', _fmt(student['amountRemaining']), color: Colors.red),
              ],
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 8),
            Text(
              'اسحب للأسفل للتحديث',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title, required this.value, required this.subtitle,
    required this.icon, required this.color,
  });
  final String title, value, subtitle;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge — top
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          // Numbers + labels — bottom, kept tight with FittedBox so big
          // values don't push siblings out of the card.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.icon, required this.color, required this.rows});
  final String title;
  final IconData icon;
  final Color color;
  final List<_SummaryRow> rows;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(r.label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const Spacer(),
                Text(r.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: r.color)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _SummaryRow {
  const _SummaryRow(this.label, this.value, {required this.color});
  final String label, value;
  final Color color;
}
