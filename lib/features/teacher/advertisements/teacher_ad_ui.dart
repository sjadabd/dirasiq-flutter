import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../shared/design/teacher_design.dart';

const adStatusLabels = <String, String>{
  'draft': 'مسودة',
  'pending_review': 'قيد المراجعة',
  'approved': 'موافق عليه',
  'rejected': 'مرفوض',
  'running': 'نشط',
  'finished': 'منتهي',
  'budget_exhausted': 'نفدت الميزانية',
};

String adStatusLabel(String? status) =>
    adStatusLabels[status ?? ''] ?? (status ?? '—');

TeacherTone adStatusTone(String? status) {
  switch (status) {
    case 'running':
    case 'approved':
      return TeacherTone.success;
    case 'pending_review':
      return TeacherTone.warning;
    case 'rejected':
    case 'budget_exhausted':
      return TeacherTone.danger;
    case 'finished':
      return TeacherTone.neutral;
    default:
      return TeacherTone.info;
  }
}

bool canRepublishAd(String status) =>
    status == 'finished' || status == 'budget_exhausted' || status == 'rejected';

bool canStopAd(String status) => status == 'approved' || status == 'running';

bool canContinueDraft(String status) =>
    status == 'draft' || status == 'pending_review';

String adCoverUrl(Object? path) {
  final p = path?.toString().trim() ?? '';
  if (p.isEmpty) return '';
  if (p.startsWith('http') || p.startsWith('data:')) return p;
  final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r'/$'), '');
  return p.startsWith('/') ? '$base$p' : '$base/$p';
}

Future<bool> confirmStopAdvertisement(BuildContext context) async {
  final mq = context.mq;
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: mq.card,
            shape: RoundedRectangleBorder(borderRadius: MqRadius.brLg),
            title: const Text('إيقاف الإعلان'),
            content: const Text(
              'هل أنت متأكد من إيقاف هذا الإعلان؟\n'
              'سيتم إيقاف العرض فوراً واسترداد الميزانية المتبقية إلى محفظتك.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('نعم، إيقاف'),
              ),
            ],
          ),
        ),
      ) ??
      false;
}
