import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/realtime_service.dart';
import '../../../core/services/teacher_api_service.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_app_bar.dart';
import '../shared/teacher_helpers.dart' show fmtIQD, adClickSpend;
import 'teacher_ad_form_screen.dart';
import 'teacher_ad_ui.dart';

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
    } catch (_) {
      Get.snackbar('خطأ', 'تعذّر تحميل الإعلان');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<void> _stop() async {
    if (!await confirmStopAdvertisement(context)) return;
    try {
      await _api.cancelAdvertisement(widget.adId);
      _toast('تم إيقاف الإعلان');
      if (mounted) Get.back(result: true);
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _republish() async {
    final ok = await Get.to(() => TeacherAdFormScreen(republishMode: true, initial: _ad));
    if (ok == true && mounted) Get.back(result: true);
  }

  Future<void> _continueDraft() async {
    final ok = await Get.to(() => TeacherAdFormScreen(adId: widget.adId, initial: _ad));
    if (ok == true) {
      await _load();
      if (mounted) Get.back(result: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final status = (_ad['status'] ?? '').toString();
    final cover = adCoverUrl(_ad['coverImageUrl'] ?? _ad['cover_image_url']);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: mq.page,
        appBar: TeacherAppBar(title: (_ad['title'] ?? 'تفاصيل الإعلان').toString()),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(MqSpacing.lg),
                children: [
                  if (cover.isNotEmpty)
                    ClipRRect(
                      borderRadius: MqRadius.brLg,
                      child: Image.network(
                        cover,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: MqSpacing.md),
                  Row(
                    children: [
                      TeacherStatusPill(
                        label: adStatusLabel(status),
                        tone: adStatusTone(status),
                      ),
                    ],
                  ),
                  const SizedBox(height: MqSpacing.md),
                  Text(
                    (_ad['description'] ?? '').toString(),
                    style: context.text.bodyMedium?.copyWith(height: 1.55),
                  ),
                  const SizedBox(height: MqSpacing.lg),
                  TeacherDashboardCard(
                    title: 'إحصائيات الإعلان',
                    icon: Icons.insights_outlined,
                    tone: TeacherTone.info,
                    child: Column(
                      children: [
                        _row(context, 'الميزانية', fmtIQD(_ad['budgetTotal'] ?? _ad['budget_total'])),
                        _row(context, 'مصروف النقرات', fmtIQD(adClickSpend(_ad))),
                        _row(context, 'المتبقي المحجوز',
                            fmtIQD(_ad['budgetRemaining'] ?? _ad['budget_remaining'])),
                        _row(context, 'سعر النقرة',
                            fmtIQD(_ad['costPerClick'] ?? _ad['cost_per_click'])),
                        _row(context, 'النقرات الفريدة',
                            (_ad['uniqueClicks'] ?? _ad['unique_clicks'] ?? 0).toString()),
                      ],
                    ),
                  ),
                  const SizedBox(height: MqSpacing.lg),
                  if (canContinueDraft(status)) ...[
                    MqButton(
                      label: 'متابعة التحرير والإرسال',
                      icon: Icons.edit_note_rounded,
                      onPressed: _continueDraft,
                    ),
                    if (status == 'draft') ...[
                      const SizedBox(height: MqSpacing.sm),
                      MqButton.secondary(
                        label: 'حذف المسودة',
                        icon: Icons.delete_outline,
                        onPressed: () async {
                          try {
                            await _api.deleteAdvertisement(widget.adId);
                            if (mounted) Get.back(result: true);
                          } catch (e) {
                            _toast(e.toString().replaceFirst('Exception: ', ''));
                          }
                        },
                      ),
                    ],
                  ],
                  if (canStopAd(status)) ...[
                    MqButton.secondary(
                      label: 'إيقاف الإعلان',
                      icon: Icons.pause_circle_outline,
                      onPressed: _stop,
                    ),
                  ],
                  if (canRepublishAd(status)) ...[
                    MqButton(
                      label: 'إعادة نشر الإعلان',
                      icon: Icons.replay_rounded,
                      onPressed: _republish,
                    ),
                    const SizedBox(height: MqSpacing.sm),
                    Text(
                      'يمكنك تعديل البيانات والصورة وتحديد ميزانية جديدة. '
                      'سيُرسل الطلب للسوبر أدمن للموافقة.',
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall?.copyWith(color: mq.ink3, height: 1.5),
                    ),
                  ],
                  if (status == 'rejected') ...[
                    const SizedBox(height: MqSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(MqSpacing.md),
                      decoration: BoxDecoration(
                        color: context.teacher.dangerSoft,
                        borderRadius: MqRadius.brMd,
                        border: Border.all(color: context.teacher.dangerLine),
                      ),
                      child: Text(
                        'سبب الرفض: ${(_ad['rejectionReason'] ?? _ad['rejection_reason'] ?? '—')}',
                        style: context.text.bodySmall?.copyWith(color: mq.error),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: context.text.bodySmall?.copyWith(color: context.mq.ink2)),
          ),
          Text(value,
              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
