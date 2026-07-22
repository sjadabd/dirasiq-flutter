import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/features/course_hub/controllers/course_hub_controller.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

/// Banner shown when the enrolled student opens a finished or soft-deleted course.
class CourseHubArchiveBanner extends StatelessWidget {
  const CourseHubArchiveBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final c = Get.find<CourseHubController>();
    return Obx(() {
      if (!c.isArchiveMode) return const SizedBox.shrink();
      final deleted = c.isCourseDeleted;
      final title = deleted ? 'هذه الدورة محذوفة' : 'هذه الدورة منتهية';
      final body = deleted
          ? 'يمكنك الاطلاع على الأرشيف فقط (البيانات السابقة). لا يتوفر تسجيل حضور أو أنشطة الدورات النشطة.'
          : 'تم تحويل الدورة إلى الأرشيف بعد انتهاء تاريخها. يمكنك مراجعة السجل السابق فقط دون أنشطة الدورات النشطة.';

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: MqSpacing.lg),
        padding: const EdgeInsets.all(MqSpacing.lg),
        decoration: BoxDecoration(
          color: mq.orangeSoft,
          borderRadius: MqRadius.brLg,
          border: Border.all(color: mq.orangeLine),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              deleted ? Icons.delete_outline_rounded : Icons.archive_outlined,
              color: mq.orangeDeep,
            ),
            MqSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleSmall?.copyWith(
                      color: mq.orangeDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: context.text.bodySmall?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MqSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: mq.page,
                      borderRadius: MqRadius.brSm,
                    ),
                    child: Text(
                      'وضع الأرشيف',
                      style: context.text.labelSmall?.copyWith(
                        color: mq.orangeDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
