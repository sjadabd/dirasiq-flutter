import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../shared/design/teacher_design.dart';
import '../shared/teacher_routes.dart';
import '../shared/teacher_workspace.dart';
import 'teacher_ad_detail_screen.dart';

/// Increment to request a reload on [TeacherAdsListScreen] (still mounted in workspace).
final teacherAdsListRefreshTick = ValueNotifier<int>(0);

void requestTeacherAdsListRefresh() {
  teacherAdsListRefreshTick.value++;
}

/// After submit/republish: switch to الإعلانات tab, refresh list, pop form/detail overlays.
void completeTeacherAdSubmitFlow(BuildContext context) {
  TeacherWorkspace.jumpTo(context, TeacherWorkspaceState.advertisementsIdx);
  requestTeacherAdsListRefresh();
  Get.until((route) {
    final name = route.settings.name;
    return name != null && TeacherRoutes.all.contains(name);
  });
}

bool isAdvertisementNotification(String? type, String? routeOrPath) {
  final t = type?.toLowerCase() ?? '';
  if (t.startsWith('advertisement_')) return true;
  final p = routeOrPath?.split('?').first.trim();
  if (p == null || p.isEmpty) return false;
  return p == '/teacher/advertisements' || p.startsWith('/teacher/advertisements/');
}

/// In-app notification tap → الإعلانات tab, optionally open ad details.
void openTeacherAdvertisementFromNotification(
  BuildContext context,
  Map<String, dynamic> payload,
  Map<String, dynamic> n,
) {
  final adId = (payload['advertisementId'] ??
          payload['advertisement_id'] ??
          n['advertisementId'] ??
          n['advertisement_id'])
      ?.toString()
      .trim();
  TeacherWorkspace.jumpTo(context, TeacherWorkspaceState.advertisementsIdx);
  if (adId != null && adId.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.to(() => TeacherAdDetailScreen(adId: adId));
    });
  }
}

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
