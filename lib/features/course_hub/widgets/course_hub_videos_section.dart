// Course Hub — Videos section (MulhimIQ design system).
//
// Hits the Phase 2 endpoint
//   GET /api/student/courses/:courseId/video-courses
// to surface the video courses pinned to this live course AND viewable
// by the student. The single list is split client-side into two rails:
//
//   - free (or owned) for this student — no buy step,
//   - paid (marketplace_paid) the student can buy without leaving the hub.
//
// Empty list → "no videos pinned to this course yet" hint. A rail with zero
// items is omitted. Data fetch + free/paid classification + navigation are
// UNCHANGED — only the presentation was restyled.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/features/course_hub/controllers/course_hub_controller.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

class CourseHubVideosSection extends StatefulWidget {
  const CourseHubVideosSection({super.key});

  @override
  State<CourseHubVideosSection> createState() => _CourseHubVideosSectionState();
}

class _CourseHubVideosSectionState extends State<CourseHubVideosSection> {
  CourseHubController get _c => Get.find<CourseHubController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.ensureSectionLoaded(CourseHubSection.videos);
    });
  }

  /// "Free" is interpreted broadly — anything the student can play right now
  /// without a purchase, including videos owned through enrollment-bypass or
  /// whitelist (green "مجاني" / owned badge, no buy step).
  bool _isFreeForStudent(Map<String, dynamic> v) {
    if (v['isFree'] == true || v['is_free'] == true) return true;
    final price = v['price'];
    if (price is num && price == 0) return true;
    if (price is String && (price == '0' || price == '0.00')) return true;
    if (v['hasAccess'] == true || v['has_access'] == true) return true;
    if (v['isOwned'] == true || v['is_owned'] == true) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mq;
    return Obx(() {
      Widget body;
      final loading = _c.videosLoading.value && _c.videos.isEmpty;
      final err = _c.videosError.value;
      if (loading) {
        body = const CourseHubSectionLoading(height: 100);
      } else if (err.isNotEmpty && _c.videos.isEmpty) {
        body = CourseHubSectionError(
          message: err,
          onRetry: () => _c.ensureSectionLoaded(CourseHubSection.videos),
        );
      } else if (_c.videos.isEmpty) {
        body = Padding(
          padding: const EdgeInsets.symmetric(vertical: MqSpacing.xs),
          child: Text('لا توجد كورسات مرئية مرتبطة بهذه الدورة بعد.',
              style: context.text.bodySmall),
        );
      } else {
        final free = _c.videos.where(_isFreeForStudent).toList();
        final paid = _c.videos.where((v) => !_isFreeForStudent(v)).toList();
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (free.isNotEmpty) ...[
              _subHeader(context, 'المجانية', free.length, MqBadgeTone.success),
              MqSpacing.gapSm,
              _buildCarousel(context, free),
              if (paid.isNotEmpty) MqSpacing.gapMd,
            ],
            if (paid.isNotEmpty) ...[
              _subHeader(context, 'المدفوعة', paid.length, MqBadgeTone.orange),
              MqSpacing.gapSm,
              _buildCarousel(context, paid),
            ],
          ],
        );
      }

      return CourseHubSectionShell(
        icon: Icons.play_circle_outline,
        iconColor: m.accent,
        title: 'الكورسات المرئية لهذه الدورة',
        badge: _c.videos.isNotEmpty
            ? CourseHubBadge(label: '${_c.videos.length}')
            : null,
        child: body,
      );
    });
  }

  Widget _subHeader(BuildContext context, String label, int count, MqBadgeTone tone) {
    return Row(
      children: [
        Text(label, style: context.text.titleSmall),
        MqSpacing.gapXs,
        MqBadge(label: '$count', tone: tone),
      ],
    );
  }

  Widget _buildCarousel(BuildContext context, List<Map<String, dynamic>> items) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.sm),
        itemBuilder: (context, i) => _buildVideoCard(context, items[i]),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, Map<String, dynamic> v) {
    final m = context.mq;
    final title = (v['title'] ?? '').toString();
    final cover = (v['coverImage'] ?? v['cover_image'] ?? '').toString();
    final fullCover = cover.isEmpty
        ? ''
        : (cover.startsWith('http') ? cover : '${AppConfig.serverBaseUrl}$cover');
    final id = (v['id'] ?? '').toString();
    final isFree = _isFreeForStudent(v);
    final price = v['price'];
    final priceLabel = (!isFree && price is num && price > 0)
        ? '${price.toInt()} د.ع'
        : (!isFree && price is String && price.isNotEmpty)
            ? price
            : '';

    return SizedBox(
      width: 180,
      child: MqCard(
        padding: EdgeInsets.zero,
        onTap: id.isEmpty
            ? null
            : () => Get.toNamed('/student/video-course-details', arguments: id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: fullCover.isEmpty
                        ? Container(
                            color: m.fill2,
                            child: Icon(Icons.play_circle_outline, size: 30, color: m.ink3),
                          )
                        : Image.network(
                            fullCover,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: m.fill2,
                              child: Icon(Icons.broken_image_outlined, color: m.ink3),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: MqBadge(
                      label: isFree ? 'مجاني' : (priceLabel.isEmpty ? 'مدفوع' : priceLabel),
                      tone: isFree ? MqBadgeTone.success : MqBadgeTone.orange,
                      solid: true,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MqSpacing.sm, vertical: MqSpacing.xs),
              child: Text(title,
                  style: context.text.labelMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
