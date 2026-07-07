import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_helpers.dart' show fmtIQD, adClickSpend;
import 'teacher_ad_form_screen.dart';

class TeacherAdDetailScreen extends StatefulWidget {
  const TeacherAdDetailScreen({super.key, required this.adId});

  final String adId;

  @override
  State<TeacherAdDetailScreen> createState() => _TeacherAdDetailScreenState();
}

class _TeacherAdDetailScreenState extends State<TeacherAdDetailScreen> {
  final _api = TeacherApiService();
  bool _loading = true;
  Map<String, dynamic> _ad = {};
  void Function()? _unsubscribeStatusChanged;

  @override
  void initState() {
    super.initState();
    _unsubscribeStatusChanged = RealtimeService.instance.subscribe(
      'advertisement:status_changed',
      (data) {
        final ad = data is Map ? data['advertisement'] : null;
        final id = ad is Map ? ad['id']?.toString() : null;
        if (id == widget.adId) _load();
      },
    );
    _load();
  }

  @override
  void dispose() {
    _unsubscribeStatusChanged?.call();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _ad = await _api.fetchAdvertisementById(widget.adId);
    } catch (e) {
      Get.snackbar('خطأ', 'تعذّر تحميل الإعلان');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _imgUrl(Object? path) {
    final p = path?.toString().trim() ?? '';
    if (p.isEmpty) return '';
    if (p.startsWith('http')) return p;
    final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r'/$'), '');
    return p.startsWith('/') ? '$base$p' : '$base/$p';
  }

  bool get _canEdit {
    final s = (_ad['status'] ?? '').toString();
    return s == 'draft' || s == 'pending_review';
  }

  @override
  Widget build(BuildContext context) {
    final status = (_ad['status'] ?? '').toString();
    final cover = _imgUrl(_ad['coverImageUrl'] ?? _ad['cover_image_url']);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: TeacherAppBar(
          title: (_ad['title'] ?? 'تفاصيل الإعلان').toString(),
          actions: [
            if (_canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final ok = await Get.to(() => TeacherAdFormScreen(adId: widget.adId, initial: _ad));
                  if (ok == true) _load();
                },
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(MqSpacing.lg),
                children: [
                  if (cover.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(cover, height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 16),
                  Text((_ad['description'] ?? '').toString()),
                  const SizedBox(height: 16),
                  _row('الحالة', status),
                  _row('الميزانية', '${fmtIQD(_ad['budgetTotal'] ?? _ad['budget_total'])} د.ع'),
                  _row('المصروف على النقرات', '${fmtIQD(adClickSpend(_ad))} د.ع'),
                  _row('المتبقي المحجوز', '${fmtIQD(_ad['budgetRemaining'] ?? _ad['budget_remaining'])} د.ع'),
                  _row('سعر النقرة', '${fmtIQD(_ad['costPerClick'] ?? _ad['cost_per_click'])} د.ع'),
                  _row('النقرات الفريدة', (_ad['uniqueClicks'] ?? _ad['unique_clicks'] ?? 0).toString()),
                  if (status == 'draft') ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await _api.deleteAdvertisement(widget.adId);
                          if (mounted) Get.back(result: true);
                        } catch (e) {
                          Get.snackbar('خطأ', e.toString().replaceFirst('Exception: ', ''));
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف المسودة'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await _api.submitAdvertisement(widget.adId);
                          Get.snackbar('تم', 'تم الإرسال للمراجعة');
                          if (mounted) Get.back(result: true);
                        } catch (e) {
                          Get.snackbar('خطأ', e.toString());
                        }
                      },
                      child: const Text('إرسال للمراجعة'),
                    ),
                  ],
                  if (status == 'approved' || status == 'running') ...[
                    const SizedBox(height: 24),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        try {
                          await _api.cancelAdvertisement(widget.adId);
                          Get.snackbar('تم', 'تم إيقاف الإعلان');
                          if (mounted) Get.back(result: true);
                        } catch (e) {
                          Get.snackbar('خطأ', e.toString().replaceFirst('Exception: ', ''));
                        }
                      },
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('إيقاف الإعلان'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
