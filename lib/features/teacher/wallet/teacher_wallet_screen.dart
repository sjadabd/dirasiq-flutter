import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/teacher_api_service.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_bottom_nav.dart';
import '../shared/teacher_helpers.dart';

/// Teacher → "المحفظة". View-only. Top-up flows are dashboard-only.
class TeacherWalletScreen extends StatefulWidget {
  const TeacherWalletScreen({super.key});
  @override
  State<TeacherWalletScreen> createState() => _TeacherWalletScreenState();
}

class _TeacherWalletScreenState extends State<TeacherWalletScreen> {
  final _api = TeacherApiService();
  bool _loading = false;
  Map<String, dynamic> _wallet = const {};

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchWallet();
      _wallet = (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : {};
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر جلب المحفظة', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final balance = _wallet['balance'];
    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة'),
          actions: [IconButton(onPressed: _loading ? null : _fetch, icon: const Icon(Icons.refresh))]),
      drawer: const TeacherDrawer(),
      bottomNavigationBar: const TeacherBottomNav(),
      body: RefreshIndicator(onRefresh: _fetch, child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kNavy, kNavy2], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text('رصيد المحفظة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(color: kOrange, backgroundColor: Colors.white24))
            else
              FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart,
                  child: Text(fmtIQD(balance), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))),
          ]),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: kOrange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kOrange.withValues(alpha: 0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.info_outline, color: kOrange, size: 18),
              SizedBox(width: 8),
              Text('شحن المحفظة', style: TextStyle(color: kOrange, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            Text('لشحن المحفظة وإدارة باقة الاشتراك، استخدم لوحة التحكم على الويب. هذه القنوات متاحة فقط في الواجهة الرئيسية للأمان.',
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7), height: 1.6)),
          ]),
        ),
      ])),
    );
  }
}
