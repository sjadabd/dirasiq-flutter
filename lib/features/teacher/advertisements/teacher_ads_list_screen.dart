import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/realtime_service.dart';
import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_drawer.dart';
import '../shared/teacher_helpers.dart' show fmtIQD, adClickSpend;
import 'teacher_ad_detail_screen.dart';
import 'teacher_ad_form_screen.dart';
import 'teacher_ad_ui.dart';

/// Teacher → "الإعلانات" — list, create, republish, stats.
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
    teacherAdsListRefreshTick.addListener(_onRefreshTick);
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

  void _onRefreshTick() {
    if (!mounted) return;
    _fetch();
  }

  @override
  void dispose() {
    teacherAdsListRefreshTick.removeListener(_onRefreshTick);
    _unsubscribeStatusChanged?.call();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await _api.fetchAdvertisements(limit: 50);
      _items = _extractAds(res);
      _stats = await _api.fetchAdvertisementStatistics();
    } catch (_) {
      _toast('تعذّر تحميل الإعلانات');
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

  Future<void> _stopAd(String id) async {
    if (!await confirmStopAdvertisement(context)) return;
    try {
      await _api.cancelAdvertisement(id);
      _toast('تم إيقاف الإعلان');
      await _fetch();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _republish(Map<String, dynamic> ad) async {
    await Get.to(() => TeacherAdFormScreen(republishMode: true, initial: ad));
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: mq.page,
        drawer: const TeacherDrawer(),
        appBar: TeacherAppBar(
          title: 'الإعلانات',
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loading ? null : _fetch,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Get.to(() => const TeacherAdFormScreen()),
          icon: const Icon(Icons.add_rounded),
          label: const Text('إعلان جديد'),
        ),
        body: RefreshIndicator(
          onRefresh: _fetch,
          color: mq.accent,
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    MqSpacing.lg,
                    MqSpacing.lg,
                    MqSpacing.lg,
                    96,
                  ),
                  children: [
                    if (_stats.isNotEmpty) _StatsSection(stats: _stats),
                    const SizedBox(height: MqSpacing.lg),
                    if (_items.isEmpty)
                      const TeacherEmptyState(
                        message: 'لا توجد إعلانات بعد.\nاضغط «إعلان جديد» لبدء حملة.',
                        icon: Icons.campaign_outlined,
                      )
                    else
                      ..._items.map((ad) => _AdCard(
                            ad: ad,
                            onTap: () async {
                              final changed =
                                  await Get.to(() => TeacherAdDetailScreen(adId: ad['id'].toString()));
                              if (changed == true) await _fetch();
                            },
                            onStop: () => _stopAd(ad['id'].toString()),
                            onRepublish: () => _republish(ad),
                            onDeleteDraft: () async {
                              await _api.deleteAdvertisement(ad['id'].toString());
                              await _fetch();
                            },
                          )),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final running = stats['runningAdvertisements'] ?? stats['running_advertisements'] ?? 0;
    final clicks = stats['uniqueStudentClicks'] ?? stats['unique_student_clicks'] ?? 0;
    final spent = stats['totalMoneySpent'] ?? stats['total_money_spent'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: TeacherKpiCard(
            label: 'نشطة',
            value: running.toString(),
            icon: Icons.play_circle_outline_rounded,
            tone: TeacherTone.success,
          ),
        ),
        const SizedBox(width: MqSpacing.sm),
        Expanded(
          child: TeacherKpiCard(
            label: 'نقرات',
            value: clicks.toString(),
            icon: Icons.touch_app_outlined,
            tone: TeacherTone.info,
          ),
        ),
        const SizedBox(width: MqSpacing.sm),
        Expanded(
          child: TeacherKpiCard(
            label: 'مصروف',
            value: fmtIQD(spent),
            icon: Icons.payments_outlined,
            tone: TeacherTone.warning,
          ),
        ),
      ],
    );
  }
}

class _AdCard extends StatelessWidget {
  const _AdCard({
    required this.ad,
    required this.onTap,
    required this.onStop,
    required this.onRepublish,
    required this.onDeleteDraft,
  });

  final Map<String, dynamic> ad;
  final VoidCallback onTap;
  final VoidCallback onStop;
  final VoidCallback onRepublish;
  final VoidCallback onDeleteDraft;

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final status = (ad['status'] ?? '').toString();
    final title = (ad['title'] ?? '').toString();
    final cover = adCoverUrl(ad['coverImageUrl'] ?? ad['cover_image_url']);
    final clicks = ad['uniqueClicks'] ?? ad['unique_clicks'] ?? 0;
    final spent = adClickSpend(ad);

    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.md),
      child: Material(
        color: mq.card,
        borderRadius: MqRadius.brLg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: mq.line),
              borderRadius: MqRadius.brLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (cover.isNotEmpty)
                  Image.network(
                    cover,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 120,
                      color: mq.fill,
                      child: Icon(Icons.campaign_outlined, color: mq.ink3, size: 40),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(MqSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: context.text.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: MqSpacing.sm),
                          TeacherStatusPill(
                            label: adStatusLabel(status),
                            tone: adStatusTone(status),
                            dense: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: MqSpacing.sm),
                      Row(
                        children: [
                          _meta(context, Icons.touch_app_outlined, '$clicks نقرة'),
                          const SizedBox(width: MqSpacing.md),
                          _meta(context, Icons.payments_outlined, 'مصروف ${fmtIQD(spent)}'),
                        ],
                      ),
                      if (canStopAd(status) ||
                          canRepublishAd(status) ||
                          status == 'draft') ...[
                        const SizedBox(height: MqSpacing.md),
                        Wrap(
                          spacing: MqSpacing.sm,
                          runSpacing: MqSpacing.xs,
                          children: [
                            if (canStopAd(status))
                              _actionChip(
                                context,
                                label: 'إيقاف',
                                icon: Icons.pause_circle_outline,
                                color: mq.error,
                                onTap: onStop,
                              ),
                            if (canRepublishAd(status))
                              _actionChip(
                                context,
                                label: 'إعادة نشر',
                                icon: Icons.replay_rounded,
                                color: mq.accent,
                                onTap: onRepublish,
                              ),
                            if (status == 'draft')
                              _actionChip(
                                context,
                                label: 'حذف',
                                icon: Icons.delete_outline,
                                color: mq.ink3,
                                onTap: onDeleteDraft,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.mq.ink3),
        const SizedBox(width: 4),
        Text(text, style: context.text.labelSmall?.copyWith(color: context.mq.ink2)),
      ],
    );
  }

  Widget _actionChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: MqRadius.brPill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: MqRadius.brPill,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: context.text.labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
