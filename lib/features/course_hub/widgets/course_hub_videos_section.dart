// Course Hub — Videos section.
//
// Hits the Phase 2 endpoint
//   GET /api/student/courses/:courseId/video-courses
// to surface the video courses pinned to this live course AND viewable
// by the student. The single list is split client-side into two rails:
//
//   - "الكورسات المرئية المجانية" — free (or owned) for this student.
//   - "الكورسات المرئية المدفوعة" — paid (marketplace_paid) the student
//                                     can buy without leaving the hub.
//
// Empty list → "no videos pinned to this course yet" hint. A row with
// zero items is simply omitted so the hub doesn't grow an empty card.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/features/course_hub/controllers/course_hub_controller.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';

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

  /// "Free" is interpreted broadly here — the row covers anything the
  /// student can play right now without a purchase, including videos
  /// owned through enrollment-bypass or whitelist. This mirrors what the
  /// student sees on the card: a green "مجاني" or indigo "مملوكة" badge,
  /// either way no buy step.
  bool _isFreeForStudent(Map<String, dynamic> v) {
    if (v['isFree'] == true || v['is_free'] == true) return true;
    final price = v['price'];
    if (price is num && price == 0) return true;
    if (price is String && (price == '0' || price == '0.00')) return true;
    // Discovery shape that already comes back from the marketplace
    // endpoint sometimes carries `hasAccess` / `isOwned` for the student.
    if (v['hasAccess'] == true || v['has_access'] == true) return true;
    if (v['isOwned'] == true || v['is_owned'] == true) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'لا توجد كورسات مرئية مرتبطة بهذه الدورة بعد.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        );
      } else {
        final free = _c.videos.where(_isFreeForStudent).toList();
        final paid = _c.videos.where((v) => !_isFreeForStudent(v)).toList();
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (free.isNotEmpty) ...[
              _subHeader(cs, 'المجانية', free.length, Colors.green),
              const SizedBox(height: 6),
              _buildCarousel(free, cs),
              if (paid.isNotEmpty) const SizedBox(height: 12),
            ],
            if (paid.isNotEmpty) ...[
              _subHeader(cs, 'المدفوعة', paid.length, Colors.orange),
              const SizedBox(height: 6),
              _buildCarousel(paid, cs),
            ],
          ],
        );
      }

      return CourseHubSectionShell(
        icon: Icons.play_circle_outline,
        iconColor: Colors.deepPurple,
        title: 'الكورسات المرئية لهذه الدورة',
        badge: _c.videos.isNotEmpty
            ? CourseHubBadge(
                label: '${_c.videos.length}', color: Colors.deepPurple)
            : null,
        child: body,
      );
    });
  }

  Widget _subHeader(ColorScheme cs, String label, int count, Color accent) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarousel(List<Map<String, dynamic>> items, ColorScheme cs) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _buildVideoCard(items[i], cs),
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> v, ColorScheme cs) {
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

    return InkWell(
      onTap: id.isEmpty
          ? null
          : () => Get.toNamed('/student/video-course-details', arguments: id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(10)),
                    child: fullCover.isEmpty
                        ? Container(
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.play_circle_outline,
                                size: 32, color: cs.onSurfaceVariant),
                          )
                        : Image.network(
                            fullCover,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.broken_image_outlined,
                                  color: cs.onSurfaceVariant),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isFree ? Colors.green : Colors.orange)
                            .withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isFree
                            ? 'مجاني'
                            : (priceLabel.isEmpty ? 'مدفوع' : priceLabel),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
