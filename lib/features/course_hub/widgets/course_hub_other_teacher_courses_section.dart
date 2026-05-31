// Course Hub — "أخرى لهذا الأستاذ" section.
//
// Small discovery section appended at the bottom of the unified Course
// Hub. Lets the student keep exploring the same teacher's catalog
// without leaving the hub. Two rails:
//
//   1. Live courses by this teacher that AREN'T this course.
//      Tap → /course-details (existing suggested-courses purchase /
//      free-access flow).
//   2. Video courses by this teacher (free + paid mixed).
//      Tap → /student/video-course-details (existing detail screen,
//      which itself renders the purchase CTA for paid+unowned).
//
// The section silently collapses when both rails are empty so the hub
// doesn't grow an empty card. Errors are swallowed inside the loader —
// the section is non-essential discovery, never a blocker.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/features/course_hub/controllers/course_hub_controller.dart';
import 'package:mulhimiq/features/course_hub/widgets/course_hub_section_shell.dart';

class CourseHubOtherTeacherCoursesSection extends StatefulWidget {
  const CourseHubOtherTeacherCoursesSection({super.key});

  @override
  State<CourseHubOtherTeacherCoursesSection> createState() =>
      _CourseHubOtherTeacherCoursesSectionState();
}

class _CourseHubOtherTeacherCoursesSectionState
    extends State<CourseHubOtherTeacherCoursesSection> {
  CourseHubController get _c => Get.find<CourseHubController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.ensureSectionLoaded(CourseHubSection.otherTeacherCourses);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final liveEmpty = _c.otherLiveCourses.isEmpty;
      final vodEmpty = _c.otherVideoCourses.isEmpty;
      final loading = _c.otherTeacherCoursesLoading.value && liveEmpty && vodEmpty;
      final err = _c.otherTeacherCoursesError.value;

      Widget body;
      if (loading) {
        body = const CourseHubSectionLoading(height: 100);
      } else if (err.isNotEmpty && liveEmpty && vodEmpty) {
        body = CourseHubSectionError(
          message: err,
          onRetry: () =>
              _c.ensureSectionLoaded(CourseHubSection.otherTeacherCourses),
        );
      } else if (liveEmpty && vodEmpty) {
        body = Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'لا توجد دورات أخرى لهذا الأستاذ حالياً.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        );
      } else {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!liveEmpty) ...[
              _subHeader(cs, 'دورات حضورية', _c.otherLiveCourses.length,
                  Colors.blue),
              const SizedBox(height: 6),
              _liveCarousel(_c.otherLiveCourses, cs),
              if (!vodEmpty) const SizedBox(height: 12),
            ],
            if (!vodEmpty) ...[
              _subHeader(
                  cs, 'كورسات مرئية', _c.otherVideoCourses.length, Colors.purple),
              const SizedBox(height: 6),
              _videoCarousel(_c.otherVideoCourses, cs),
            ],
          ],
        );
      }

      // Hide the entire shell when there's nothing AND we're not loading
      // AND there's no error — the hub stays clean for teachers with a
      // single offering.
      if (liveEmpty && vodEmpty && !loading && err.isEmpty) {
        return const SizedBox.shrink();
      }

      return CourseHubSectionShell(
        icon: Icons.explore_outlined,
        iconColor: Colors.teal,
        title: 'أخرى لهذا الأستاذ',
        badge: (liveEmpty && vodEmpty)
            ? null
            : CourseHubBadge(
                label:
                    '${_c.otherLiveCourses.length + _c.otherVideoCourses.length}',
                color: Colors.teal,
              ),
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

  // ─── Live courses rail ─────────────────────────────────────────────

  Widget _liveCarousel(List<Map<String, dynamic>> items, ColorScheme cs) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _liveCard(items[i], cs),
      ),
    );
  }

  Widget _liveCard(Map<String, dynamic> c, ColorScheme cs) {
    final id = (c['id'] ?? '').toString();
    final name = (c['course_name'] ?? c['name'] ?? 'دورة').toString();
    final images = (c['course_images'] is List)
        ? c['course_images'] as List
        : const [];
    final imgRaw = images.isNotEmpty ? images.first?.toString() ?? '' : '';
    final img = imgRaw.isEmpty
        ? ''
        : (imgRaw.startsWith('http') ? imgRaw : '${AppConfig.serverBaseUrl}$imgRaw');

    final priceNum = (c['price'] is num)
        ? (c['price'] as num).toDouble()
        : double.tryParse(c['price']?.toString() ?? '0') ?? 0;
    final priceLabel = priceNum > 0
        ? '${NumberFormat('#,###').format(priceNum)} د.ع'
        : 'مجاني';

    return InkWell(
      onTap: id.isEmpty
          ? null
          : () => Get.toNamed('/course-details', arguments: id),
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
                    child: img.isEmpty
                        ? Container(
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.school,
                                size: 30, color: cs.onSurfaceVariant),
                          )
                        : Image.network(
                            img,
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
                        color: (priceNum > 0 ? Colors.orange : Colors.green)
                            .withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        priceLabel,
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
                name,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Video courses rail ────────────────────────────────────────────

  Widget _videoCarousel(List<Map<String, dynamic>> items, ColorScheme cs) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _videoCard(items[i], cs),
      ),
    );
  }

  bool _isFreeForStudent(Map<String, dynamic> v) {
    if (v['isFree'] == true || v['is_free'] == true) return true;
    final price = v['price'];
    if (price is num && price == 0) return true;
    if (price is String && (price == '0' || price == '0.00')) return true;
    if (v['hasAccess'] == true || v['has_access'] == true) return true;
    if (v['isOwned'] == true || v['is_owned'] == true) return true;
    return false;
  }

  Widget _videoCard(Map<String, dynamic> v, ColorScheme cs) {
    final id = (v['id'] ?? '').toString();
    final title = (v['title'] ?? v['name'] ?? 'كورس مرئي').toString();
    final cover = (v['coverImage'] ?? v['cover_image'] ?? '').toString();
    final fullCover = cover.isEmpty
        ? ''
        : (cover.startsWith('http') ? cover : '${AppConfig.serverBaseUrl}$cover');
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
                                size: 30, color: cs.onSurfaceVariant),
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
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
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
