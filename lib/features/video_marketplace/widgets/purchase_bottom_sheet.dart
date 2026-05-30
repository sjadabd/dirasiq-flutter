// Phase 7 — Purchase bottom sheet.
//
// Shown when the student opens a marketplace-paid course they don't own.
// Displays price + a single "Purchase" button. On tap, hits the backend
// to mint a Wayl payment link and launches it externally. The webhook
// flips the purchase to `paid` and My Library refreshes on the next
// marketplace open.
//
// Designed as a screen-agnostic helper — caller passes the course map and
// the controller; this widget owns the loading state for its own button.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/video_marketplace_controller.dart';

class PurchaseBottomSheet extends StatelessWidget {
  const PurchaseBottomSheet({
    super.key,
    required this.course,
    required this.controller,
  });

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تعذّر بدء عملية الشراء. حاول مرة أخرى.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('رابط الدفع غير صالح.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تعذّر فتح صفحة الدفع.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.shopping_bag_outlined, color: cs.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('شراء الدورة',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 12),
          Text(_title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.attach_money_outlined, size: 18),
              const SizedBox(width: 6),
              const Text('السعر',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${_price.toInt()} د.ع',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: cs.primary),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Text(
            'سيُفتح موقع Wayl لإتمام الدفع. بعد نجاحه ستظهر الدورة في "مكتبتي" تلقائياً.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final busy = controller.purchasing.contains(_id);
            return FilledButton.icon(
              onPressed: busy ? null : () => _onPurchase(context),
              icon: busy
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_open_outlined),
              label: Text(busy ? 'جارٍ التحضير…' : 'متابعة إلى الدفع'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
            );
          }),
        ],
      ),
    );
  }
}
