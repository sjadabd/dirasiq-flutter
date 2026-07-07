import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/realtime_service.dart';
import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_helpers.dart' show fmtIQD;
import 'teacher_ad_detail_screen.dart';
import 'teacher_ad_form_screen.dart';

const _statusLabels = <String, String>{
  'draft': 'مسودة',
  'pending_review': 'قيد المراجعة',
  'approved': 'موافق عليه',
  'rejected': 'مرفوض',
  'running': 'نشط',
  'finished': 'منتهي',
  'budget_exhausted': 'نفدت الميزانية',
};

/// Teacher → "الإعلانات" — list, create, submit, stats summary.
class TeacherAdsListScreen extends StatefulWidget {
  const TeacherAdsListScreen({super.key});

  @override
  State<TeacherAdsListScreen> createState() => _TeacherAdsListScreenState();
}

class _TeacherAdsListScreenState extends State<TeacherAdsListScreen> {
  final _api = TeacherApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _stats = {};
  void Function()? _unsubscribeStatusChanged;

  @override
  void initState() {
    super.initState();
    _unsubscribeStatusChanged = RealtimeService.instance.subscribe(
      'advertisement:status_changed',
      (_) => _fetch(),
    );
    _fetch();
    final args = Get.arguments;
    if (args is Map && args['advertisementId'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.to(() => TeacherAdDetailScreen(adId: args['advertisementId'].toString()));
      });
    }
  }

  @override
  void dispose() {
    _unsubscribeStatusChanged?.call();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchAdvertisements(limit: 50);
      _items = _extractAds(res);
      final statsRes = await _api.fetchAdvertisementStatistics();
      _stats = statsRes;
    } catch (e) {
      Get.snackbar('خطأ', 'تعذّر تحميل الإعلانات', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _extractAds(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is List) {
      return data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    return const [];
  }

  String _label(String? status) => _statusLabels[status ?? ''] ?? (status ?? '—');

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: mq.page,
        drawer: const TeacherDrawer(),
        appBar: const TeacherAppBar(title: 'الإعلانات'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await Get.to(() => const TeacherAdFormScreen());
            if (created == true) _fetch();
          },
          icon: const Icon(Icons.add),
          label: const Text('إعلان جديد'),
        ),
        body: RefreshIndicator(
          onRefresh: _fetch,
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(MqSpacing.lg),
                  children: [
                    if (_stats.isNotEmpty) _StatsRow(stats: _stats),
                    const SizedBox(height: MqSpacing.lg),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Text('لا توجد إعلانات بعد')),
                      )
                    else
                      ..._items.map((ad) {
                        final id = (ad['id'] ?? '').toString();
                        final status = (ad['status'] ?? '').toString();
                        final canDelete = status == 'draft';
                        final canCancel = status == 'approved' || status == 'running';
                        return Card(
                          margin: const EdgeInsets.only(bottom: MqSpacing.md),
                          child: ListTile(
                            title: Text((ad['title'] ?? '').toString()),
                            subtitle: Text(
                              '${_label(status)} • ${fmtIQD(ad['budgetTotal'] ?? ad['budget_total'])} د.ع',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                if (canDelete)
                                  IconButton(
                                    tooltip: 'حذف المسودة',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await _api.deleteAdvertisement(id);
                                      await _fetch();
                                    },
                                  ),
                                if (canCancel)
                                  IconButton(
                                    tooltip: 'إيقاف الإعلان',
                                    icon: const Icon(Icons.pause_circle_outline),
                                    onPressed: () async {
                                      await _api.cancelAdvertisement(id);
                                      await _fetch();
                                    },
                                  ),
                                const Icon(Icons.chevron_left),
                              ],
                            ),
                            onTap: () async {
                              final changed = await Get.to(() => TeacherAdDetailScreen(adId: id));
                              if (changed == true) await _fetch();
                            },
                          ),
                        );
                      }),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final running = stats['runningAdvertisements'] ?? stats['running_advertisements'] ?? 0;
    final clicks = stats['uniqueStudentClicks'] ?? stats['unique_student_clicks'] ?? 0;
    final spent = stats['totalMoneySpent'] ?? stats['total_money_spent'] ?? 0;
    return Row(
      children: [
        Expanded(child: _pill('نشطة', running.toString())),
        const SizedBox(width: 8),
        Expanded(child: _pill('نقرات', clicks.toString())),
        const SizedBox(width: 8),
        Expanded(child: _pill('مصروف', fmtIQD(spent))),
      ],
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
