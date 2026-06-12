// Video purchase bottom sheet (MulhimIQ design system).
//
// Shown when a student opens a marketplace-paid course they don't own. The
// purchase flow is UNCHANGED: controller.purchase() mints a Wayl payment link
// and it's launched externally; the webhook flips the purchase to `paid` and
// My Library refreshes on return. Only the presentation was restyled.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';
import '../controllers/video_marketplace_controller.dart';

class PurchaseBottomSheet extends StatelessWidget {
  const PurchaseBottomSheet({super.key, required this.course, required this.controller});

  final Map<String, dynamic> course;
  final VideoMarketplaceController controller;

  String get _title => (course['title'] ?? course['name'] ?? '—').toString();
  String get _id => (course['id'] ?? '').toString();

  num get _price {
    final p = course['price'];
    if (p is num) return p;
    if (p is String) return num.tryParse(p) ?? 0;
    return 0;
  }

  Future<void> _onPurchase(BuildContext context) async {
    final url = await controller.purchase(_id);
    if (!context.mounted) return;
    if (url == null || url.isEmpty) {
      _snack(context, 'تعذّر بدء عملية الشراء. حاول مرة أخرى.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _snack(context, 'رابط الدفع غير صالح.');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!launched) {
      _snack(context, 'تعذّر فتح صفحة الدفع.');
      return;
    }
    Navigator.of(context).pop();
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            final m = context.mq;
            return Container(
              decoration: BoxDecoration(
                color: m.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: MqSpacing.lg, right: MqSpacing.lg, top: MqSpacing.md,
                bottom: MediaQuery.of(context).viewInsets.bottom + MqSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: m.line, borderRadius: MqRadius.brPill),
                    ),
                  ),
                  MqSpacing.gapMd,
                  Row(children: [
                    Icon(Icons.shopping_bag_outlined, color: m.accent, size: MqSize.iconMd),
                    MqSpacing.gapSm,
                    Expanded(child: Text('شراء الدورة', style: context.text.titleMedium)),
                  ]),
                  MqSpacing.gapSm,
                  Text(_title, style: context.text.titleSmall),
                  MqSpacing.gapMd,
                  MqSurface(
                    tone: MqSurfaceTone.accent,
                    padding: const EdgeInsets.all(MqSpacing.md),
                    child: Row(children: [
                      Icon(Icons.payments_outlined, size: MqSize.iconSm, color: m.accent),
                      MqSpacing.gapXs,
                      Text('السعر', style: context.text.titleSmall),
                      const Spacer(),
                      Text('${_price.toInt()} د.ع',
                          style: context.text.titleMedium?.copyWith(color: m.accent, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  MqSpacing.gapSm,
                  Text('سيُفتح موقع Wayl لإتمام الدفع. بعد نجاحه ستظهر الدورة في "مكتبتي" تلقائياً.',
                      style: context.text.bodySmall),
                  MqSpacing.gapLg,
                  Obx(() {
                    final busy = controller.purchasing.contains(_id);
                    return MqButton(
                      label: busy ? 'جارٍ التحضير…' : 'متابعة إلى الدفع',
                      icon: Icons.lock_open_outlined,
                      loading: busy,
                      onPressed: busy ? null : () => _onPurchase(context),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
