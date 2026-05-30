// Phase 7 — Video Marketplace screen.
//
// Surfaces curated sections (My Library first, then Trending / Popular /
// Newest / Recommended) in one vertical scroll. Filter chip lives in the
// app bar; tapping it opens [FiltersSheet]. Pull-to-refresh re-fetches
// every section. Errors are surfaced per-surface (marketplace vs library)
// so one bad query doesn't blank the whole screen.
//
// Tapping a card routes to the existing course detail screen
// ([StudentVideoCourseDetailScreen]) which is responsible for the
// access-aware playback gating: free / owned → lesson list + player;
// paid + unowned → opens the [PurchaseBottomSheet] from this screen.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../student/video_courses/student_video_course_detail_screen.dart';
import '../controllers/video_marketplace_controller.dart';
import '../widgets/filters_sheet.dart';
import '../widgets/marketplace_section_carousel.dart';
import '../widgets/purchase_bottom_sheet.dart';

class VideoMarketplaceScreen extends StatefulWidget {
  const VideoMarketplaceScreen({super.key});

  @override
  State<VideoMarketplaceScreen> createState() =>
      _VideoMarketplaceScreenState();
}

class _VideoMarketplaceScreenState extends State<VideoMarketplaceScreen> {
  late final VideoMarketplaceController _c;

  @override
  void initState() {
    super.initState();
    _c = Get.put(VideoMarketplaceController(), tag: 'video-marketplace');
  }

  @override
  void dispose() {
    Get.delete<VideoMarketplaceController>(tag: 'video-marketplace');
    super.dispose();
  }

  Future<void> _openFilters() async {
    final next = await showModalBottomSheet<VideoMarketplaceFilters>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FiltersSheet(
        initial: _c.filters.value,
        gradeOptions: const [],
        subjectOptions: const [],
      ),
    );
    if (next != null) await _c.applyFilters(next);
  }

  Future<void> _onTapCourse(Map<String, dynamic> course) async {
    final id = (course['id'] ?? '').toString();
    if (id.isEmpty) return;

    final isOwned = course['isOwned'] == true ||
        course['is_owned'] == true ||
        course['hasAccess'] == true ||
        course['has_access'] == true;
    final isFree = course['isFree'] == true ||
        course['is_free'] == true ||
        course['price'] == 0;

    if (isOwned || isFree) {
      await Get.to(() => StudentVideoCourseDetailScreen(courseId: id));
      // Refresh library on return — a just-watched course might now be
      // tracked in a future progress endpoint, and the badge state is
      // cheap to recompute.
      await _c.refreshAll();
      return;
    }

    // Paid + unowned → purchase sheet.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => PurchaseBottomSheet(course: course, controller: _c),
    );
    // After the user returns from Wayl, re-fetch so a newly-paid course
    // moves into My Library.
    await _c.refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدورات المرئية'),
        actions: [
          Obx(() {
            final count = _c.filters.value.activeCount;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune),
                  tooltip: 'تصفية',
                ),
                if (count > 0)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      width: 16, height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _c.refreshAll,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Obx(() {
              if (_c.filters.value.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final chip in _activeFilterChips(_c.filters.value))
                      Chip(
                        label: Text(chip,
                            style: const TextStyle(fontSize: 11)),
                        backgroundColor:
                            cs.primary.withValues(alpha: 0.1),
                        side: BorderSide(
                            color: cs.primary.withValues(alpha: 0.3)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ActionChip(
                      label: const Text('مسح الكل',
                          style: TextStyle(fontSize: 11)),
                      avatar: const Icon(Icons.close, size: 14),
                      onPressed: _c.clearFilters,
                    ),
                  ],
                ),
              );
            }),
            Obx(() {
              if (_c.libraryLoading.value && _c.myLibrary.isEmpty) {
                return _buildSkeletonSection('مكتبتي');
              }
              if (_c.libraryError.value.isNotEmpty && _c.myLibrary.isEmpty) {
                return _buildSectionError(
                  title: 'مكتبتي',
                  message: _c.libraryError.value,
                  onRetry: _c.refreshAll,
                );
              }
              return MarketplaceSectionCarousel(
                title: 'مكتبتي',
                subtitle: 'الدورات التي تملكها أو لديك وصول إليها',
                icon: Icons.library_books_outlined,
                accent: Colors.indigo,
                items: _c.myLibrary,
                showOwnedBadge: true,
                emptyMessage: 'لم تشترِ أو تنضم لأي دورة مرئية بعد.',
                onTapCourse: _onTapCourse,
              );
            }),
            Obx(() {
              if (_c.marketplaceLoading.value &&
                  _c.trending.isEmpty &&
                  _c.popular.isEmpty &&
                  _c.newest.isEmpty &&
                  _c.recommended.isEmpty) {
                return Column(
                  children: [
                    _buildSkeletonSection('الرائج'),
                    _buildSkeletonSection('الأكثر شعبية'),
                  ],
                );
              }
              if (_c.marketplaceError.value.isNotEmpty &&
                  _c.trending.isEmpty &&
                  _c.popular.isEmpty &&
                  _c.newest.isEmpty &&
                  _c.recommended.isEmpty) {
                return _buildSectionError(
                  title: 'المتجر',
                  message: _c.marketplaceError.value,
                  onRetry: _c.refreshAll,
                );
              }
              return Column(
                children: [
                  MarketplaceSectionCarousel(
                    title: 'الرائج الآن',
                    subtitle: 'الأكثر مشاهدة هذا الأسبوع',
                    icon: Icons.local_fire_department_outlined,
                    accent: Colors.deepOrange,
                    items: _c.trending,
                    onTapCourse: _onTapCourse,
                  ),
                  MarketplaceSectionCarousel(
                    title: 'الأكثر شعبية',
                    subtitle: 'الدورات الأعلى تقييماً',
                    icon: Icons.star_outline,
                    accent: Colors.amber.shade700,
                    items: _c.popular,
                    onTapCourse: _onTapCourse,
                  ),
                  MarketplaceSectionCarousel(
                    title: 'الأحدث',
                    subtitle: 'أُضيفت مؤخراً',
                    icon: Icons.fiber_new_outlined,
                    accent: Colors.teal,
                    items: _c.newest,
                    onTapCourse: _onTapCourse,
                  ),
                  MarketplaceSectionCarousel(
                    title: 'مقترحة لك',
                    subtitle: 'مبنية على مرحلتك ومواد كورساتك',
                    icon: Icons.recommend_outlined,
                    accent: Colors.deepPurple,
                    items: _c.recommended,
                    onTapCourse: _onTapCourse,
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  List<String> _activeFilterChips(VideoMarketplaceFilters f) {
    final out = <String>[];
    if (f.gradeId != null && f.gradeId!.isNotEmpty) out.add('المرحلة');
    if (f.subject != null && f.subject!.isNotEmpty) out.add('المادة: ${f.subject}');
    if (f.teacherId != null && f.teacherId!.isNotEmpty) out.add('معلّم محدد');
    if (f.minPrice != null) out.add('من ${f.minPrice}');
    if (f.maxPrice != null) out.add('حتى ${f.maxPrice}');
    return out;
  }

  Widget _buildSkeletonSection(String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, _) => Container(
                width: 180,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionError({
    required String title,
    required String message,
    required Future<void> Function() onRetry,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.error_outline, color: cs.error),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('إعادة'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
