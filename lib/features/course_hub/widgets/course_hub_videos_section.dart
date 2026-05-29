// Course Hub — Videos section.
//
// Hits the Phase 2 endpoint
//   GET /api/student/courses/:courseId/video-courses
// to surface the video courses pinned to this live course AND viewable
// by the student. Renders a horizontal carousel of mini-cards.
//
// Empty list is not an error — the section just shows a "no videos
// pinned to this course yet" hint. The teacher's other marketplace
// catalog lives in the global Video Marketplace screen and is reached
// through a different entry point.

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
        body = SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _c.videos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _buildVideoCard(_c.videos[i], cs),
          ),
        );
      }

      return CourseHubSectionShell(
        icon: Icons.play_circle_outline,
        iconColor: Colors.deepPurple,
        title: 'الكورسات المرئية',
        badge: _c.videos.isNotEmpty
            ? CourseHubBadge(label: '${_c.videos.length}', color: Colors.deepPurple)
            : null,
        child: body,
      );
    });
  }

  Widget _buildVideoCard(Map<String, dynamic> v, ColorScheme cs) {
    final title = (v['title'] ?? '').toString();
    final cover = (v['coverImage'] ?? v['cover_image'] ?? '').toString();
    final fullCover = cover.isEmpty
        ? ''
        : (cover.startsWith('http') ? cover : '${AppConfig.serverBaseUrl}$cover');
    final id = (v['id'] ?? '').toString();
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
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: fullCover.isEmpty
                    ? Container(
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.play_circle_outline,
                            size: 32, color: cs.onSurfaceVariant),
                      )
                    : Image.network(fullCover, fit: BoxFit.cover, errorBuilder: (_, _, _) {
                        return Container(
                          color: cs.surfaceContainerHighest,
                          child: Icon(Icons.broken_image_outlined,
                              color: cs.onSurfaceVariant),
                        );
                      }),
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
