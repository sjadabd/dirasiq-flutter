// Student → Video courses marketplace (MulhimIQ design-system pass).
//
// Opened from the Student Home "عرض الكل" on the recommended-videos rail
// (route /student/video-marketplace). Backed by the existing
// VideoMarketplaceController (fetchVideoMarketplace + fetchMyVideoLibrary).
// The data fetch, the owned/free/paid access routing, and the purchase flow
// are UNCHANGED — only the presentation was restyled into a single
// filter-driven "الدورات المرئية" page:
//
//   • "مكتبتي" continue-watching row (shown only when the student owns
//     courses — progress + "متابعة المشاهدة" come from the card).
//   • Filter chips (الكل / مجانية / مدفوعة / جديدة / الأكثر مشاهدة) selecting
//     which view of the marketplace data to show. مجانية/مدفوعة filter by
//     price client-side; جديدة = the backend `newest` set; الأكثر مشاهدة =
//     the backend `trending` set — no new API params, no fake data.
//   • Client-side search over the active list (no search param on the API).
//
// Tapping a card: owned/free → StudentVideoCourseDetailScreen; paid+unowned →
// PurchaseBottomSheet (both preserved from the original screen).

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mulhimiq/shared/design_system/design_system.dart';
import '../../student/video_courses/student_video_course_detail_screen.dart';
import '../controllers/video_marketplace_controller.dart';
import '../widgets/marketplace_section_carousel.dart';
import '../widgets/purchase_bottom_sheet.dart';
import '../widgets/video_course_card.dart';

class VideoMarketplaceScreen extends StatefulWidget {
  const VideoMarketplaceScreen({super.key});

  @override
  State<VideoMarketplaceScreen> createState() => _VideoMarketplaceScreenState();
}

class _VideoMarketplaceScreenState extends State<VideoMarketplaceScreen> {
  late final VideoMarketplaceController _c;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all'; // all | free | paid | new | popular

  @override
  void initState() {
    super.initState();
    _c = Get.put(VideoMarketplaceController(), tag: 'video-marketplace');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    Get.delete<VideoMarketplaceController>(tag: 'video-marketplace');
    super.dispose();
  }

  // ─── access routing (preserved) ─────────────────────────────────────────────

  bool _isOwned(Map<String, dynamic> c) =>
      c['isOwned'] == true || c['is_owned'] == true || c['hasAccess'] == true || c['has_access'] == true;
  bool _isFree(Map<String, dynamic> c) => c['isFree'] == true || c['is_free'] == true || c['price'] == 0;

  Future<void> _onTapCourse(Map<String, dynamic> course) async {
    final id = (course['id'] ?? '').toString();
    if (id.isEmpty) return;
    if (_isOwned(course) || _isFree(course)) {
      await Get.to(() => StudentVideoCourseDetailScreen(courseId: id));
      await _c.refreshAll();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PurchaseBottomSheet(course: course, controller: _c),
    );
    await _c.refreshAll();
  }

  // ─── list composition ───────────────────────────────────────────────────────

  List<Map<String, dynamic>> _merged() {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final list in [_c.recommended, _c.trending, _c.newest, _c.popular]) {
      for (final c in list) {
        final id = (c['id'] ?? '').toString();
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        out.add(c);
      }
    }
    return out;
  }

  List<Map<String, dynamic>> _activeList() {
    List<Map<String, dynamic>> base = switch (_filter) {
      'new' => _c.newest.toList(),
      'popular' => _c.trending.toList(),
      'free' => _merged().where(_isFree).toList(),
      'paid' => _merged().where((c) => !_isFree(c)).toList(),
      _ => _merged(),
    };
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      base = base.where((c) {
        final t = (c['title'] ?? c['name'] ?? '').toString().toLowerCase();
        final teacher = (c['teacherName'] ?? c['teacher_name'] ?? '').toString().toLowerCase();
        final subject = (c['subject'] ?? c['subjectName'] ?? c['subject_name'] ?? '').toString().toLowerCase();
        return t.contains(q) || teacher.contains(q) || subject.contains(q);
      }).toList();
    }
    return base;
  }

  // ─── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Scaffold(
              backgroundColor: context.mq.page,
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('الدورات المرئية'),
                    Text('اكتشف الدورات التعليمية المرئية', style: context.text.bodySmall),
                  ],
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(96),
                  child: _searchAndFilters(context),
                ),
              ),
              body: RefreshIndicator(onRefresh: _c.refreshAll, child: Obx(() => _body(context))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchAndFilters(BuildContext context) {
    final m = context.mq;
    const chips = [
      ('all', 'الكل'),
      ('free', 'مجانية'),
      ('paid', 'مدفوعة'),
      ('new', 'جديدة'),
      ('popular', 'الأكثر مشاهدة'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, 0, MqSpacing.lg, MqSpacing.sm),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            style: context.text.bodyMedium,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'ابحث في الدورات المرئية…',
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: m.ink3),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: m.fill,
              border: OutlineInputBorder(borderRadius: MqRadius.brMd, borderSide: BorderSide(color: m.line)),
              enabledBorder: OutlineInputBorder(borderRadius: MqRadius.brMd, borderSide: BorderSide(color: m.line)),
              focusedBorder: OutlineInputBorder(borderRadius: MqRadius.brMd, borderSide: BorderSide(color: m.accent)),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                    ),
            ),
          ),
          MqSpacing.gapSm,
          SizedBox(
            height: MqSize.chipHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.xs),
              itemBuilder: (_, i) => MqChip(
                label: chips[i].$2,
                selected: _filter == chips[i].$1,
                onTap: () => setState(() => _filter = chips[i].$1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final allEmpty = _c.trending.isEmpty && _c.popular.isEmpty && _c.newest.isEmpty && _c.recommended.isEmpty;
    if (_c.marketplaceLoading.value && allEmpty && _c.myLibrary.isEmpty) return _skeleton(context);
    if (_c.marketplaceError.value.isNotEmpty && allEmpty) return _errorView(context);

    final list = _activeList();
    final showLibrary = _c.myLibrary.isNotEmpty && _query.isEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: MqSpacing.xxxl + MqSpacing.xl),
      children: [
        if (showLibrary)
          MarketplaceSectionCarousel(
            title: 'مكتبتي',
            subtitle: 'تابع المشاهدة من حيث توقفت',
            icon: Icons.library_books_outlined,
            items: _c.myLibrary,
            onTapCourse: _onTapCourse,
          ),
        if (showLibrary)
          Padding(
            padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xs),
            child: Text('كل الدورات المرئية', style: context.text.titleSmall),
          ),
        if (list.isEmpty)
          _empty(context)
        else
          GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 250,
              crossAxisSpacing: MqSpacing.sm,
              mainAxisSpacing: MqSpacing.sm,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => VideoCourseCard(course: list[i], onTap: () => _onTapCourse(list[i])),
          ),
      ],
    );
  }

  // ─── states ─────────────────────────────────────────────────────────────────

  Widget _empty(BuildContext context) {
    final m = context.mq;
    final filtering = _query.isNotEmpty || _filter != 'all';
    return Padding(
      padding: const EdgeInsets.all(MqSpacing.lg),
      child: Center(child: Column(children: [
        const SizedBox(height: MqSpacing.xl),
        Container(
          padding: const EdgeInsets.all(MqSpacing.lg),
          decoration: BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
          child: Icon(Icons.video_library_outlined, size: 44, color: m.accent),
        ),
        MqSpacing.gapMd,
        Text(filtering ? 'لا توجد دورات مطابقة' : 'لا توجد دورات مرئية بعد', style: context.text.titleMedium),
        MqSpacing.gapXs,
        Text(filtering ? 'جرّب تعديل البحث أو الفلاتر.' : 'سيتم عرض الدورات المرئية المناسبة قريباً.',
            textAlign: TextAlign.center, style: context.text.bodySmall),
      ])),
    );
  }

  Widget _errorView(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 44, color: m.error),
          MqSpacing.gapMd,
          Text(_c.marketplaceError.value, textAlign: TextAlign.center, style: context.text.bodyMedium),
          MqSpacing.gapMd,
          MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: _c.refreshAll),
        ])),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 250,
        crossAxisSpacing: MqSpacing.sm,
        mainAxisSpacing: MqSpacing.sm,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => MqCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(aspectRatio: 16 / 9, child: Container(color: m.fill2)),
          Padding(
            padding: const EdgeInsets.all(MqSpacing.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 12, width: double.infinity, color: m.fill2),
              const SizedBox(height: 6),
              Container(height: 10, width: 80, color: m.fill2),
            ]),
          ),
        ]),
      ),
    );
  }
}
