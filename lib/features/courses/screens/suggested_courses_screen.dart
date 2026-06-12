// Student → Courses (MulhimIQ design-system pass). RootShell tab + standalone
// route (/suggested-courses).
//
// Backed ONLY by ApiService.fetchSuggestedCourses → GET /student/courses/
// suggested, which returns PHYSICAL (in-person, location-based) courses for the
// student's grade, distance-sorted. The recommendation + pagination logic is
// unchanged. The endpoint exposes: course_name, subject_name, grade_name,
// teacher_name, course_images, price, seats_count, distance, bookingStatus.
//
// It does NOT expose a course type (every row is in-person → a "حضوري" badge),
// a rating, or any video-course data (video courses are a separate endpoint /
// screen). So the rating field, and the مرئية / مباشر filters + the مرئية
// section, are intentionally not rendered (no fake data, no empty groups). The
// endpoint has no search param, so search + free/paid filtering run
// client-side over the already-loaded courses. The card opens the existing
// /course-details route; there is no card-level enroll CTA (booking happens
// inside course details), so no "اشترك الآن" button is shown here.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'package:mulhimiq/shared/widgets/app_network_image.dart';

class SuggestedCoursesScreen extends StatefulWidget {
  const SuggestedCoursesScreen({super.key});

  @override
  State<SuggestedCoursesScreen> createState() => _SuggestedCoursesScreenState();
}

class _SuggestedCoursesScreenState extends State<SuggestedCoursesScreen> {
  final _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  String _query = '';
  String _filter = 'all'; // all | free | paid

  final _money = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    _fetchCourses();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore && _query.isEmpty) _fetchCourses(loadMore: true);
    }
  }

  Future<void> _fetchCourses({bool loadMore = false}) async {
    try {
      if (loadMore) {
        setState(() => _loadingMore = true);
      } else {
        setState(() {
          _loading = true;
          _error = null;
          _page = 1;
          _courses.clear();
        });
      }

      final res = await _api.fetchSuggestedCourses(page: _page, limit: 8, maxDistance: 10.0);
      final newCourses = List<Map<String, dynamic>>.from(res);

      setState(() {
        if (loadMore) {
          _courses.addAll(newCourses);
        } else {
          _courses = newCourses;
        }
        _hasMore = newCourses.length == 8;
        _page++;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() {
        _error = 'حدث خطأ أثناء تحميل الدورات';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  double _priceOf(Map<String, dynamic> c) => double.tryParse(c['price'].toString()) ?? 0;
  bool _isFree(Map<String, dynamic> c) => _priceOf(c) <= 0;

  List<Map<String, dynamic>> get _visible {
    Iterable<Map<String, dynamic>> out = _courses;
    if (_filter == 'free') out = out.where(_isFree);
    if (_filter == 'paid') out = out.where((c) => !_isFree(c));
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((c) {
        final n = (c['course_name'] ?? '').toString().toLowerCase();
        final s = (c['subject_name'] ?? '').toString().toLowerCase();
        final t = (c['teacher_name'] ?? '').toString().toLowerCase();
        final g = (c['grade_name'] ?? '').toString().toLowerCase();
        return n.contains(q) || s.contains(q) || t.contains(q) || g.contains(q);
      });
    }
    return out.toList();
  }

  String _resolveImage(Map<String, dynamic> c) {
    final imgs = c['course_images'] as List?;
    if (imgs != null && imgs.isNotEmpty) {
      final p = imgs.first.toString();
      if (p.startsWith('http')) return p;
      return '${AppConfig.serverBaseUrl}$p';
    }
    return '';
  }

  // ── build ───────────────────────────────────────────────────────────────────

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
                automaticallyImplyLeading: Navigator.of(context).canPop(),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('الدورات'),
                    Text('اكتشف الدورات المناسبة لك', style: context.text.bodySmall),
                  ],
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(96),
                  child: _searchAndFilters(context),
                ),
              ),
              body: RefreshIndicator(
                onRefresh: () => _fetchCourses(loadMore: false),
                child: _body(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchAndFilters(BuildContext context) {
    final m = context.mq;
    return Padding(
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, 0, MqSpacing.lg, MqSpacing.sm),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            style: context.text.bodyMedium,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'ابحث عن دورة…',
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
          Row(children: [
            _chip(context, 'all', 'الكل'),
            const SizedBox(width: MqSpacing.xs),
            _chip(context, 'free', 'مجانية'),
            const SizedBox(width: MqSpacing.xs),
            _chip(context, 'paid', 'مدفوعة'),
          ]),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String key, String label) {
    return MqChip(label: label, selected: _filter == key, onTap: () => setState(() => _filter = key));
  }

  Widget _body(BuildContext context) {
    if (_loading) return _skeleton(context);
    if (_error != null) return _errorView(context);
    final items = _visible;
    if (items.isEmpty) return _empty(context);

    return GridView.builder(
      controller: _scrollController,
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.xxxl + MqSpacing.xl),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 252,
        crossAxisSpacing: MqSpacing.sm,
        mainAxisSpacing: MqSpacing.sm,
      ),
      itemCount: items.length + (_loadingMore && _query.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        return _courseCard(context, items[index]);
      },
    );
  }

  Widget _courseCard(BuildContext context, Map<String, dynamic> c) {
    final m = context.mq;
    final isFree = _isFree(c);
    final imgUrl = _resolveImage(c);
    final subject = (c['subject_name'] ?? '').toString();
    final grade = (c['grade_name'] ?? '').toString();
    final teacher = (c['teacher_name'] ?? '').toString();
    final seatsRaw = c['seats_count'];
    final seats = (seatsRaw is num) ? seatsRaw.toInt() : int.tryParse(seatsRaw?.toString() ?? '') ?? 0;
    final distance = c['distance'];
    final distStr = distance is num ? '${distance.toStringAsFixed(1)} كم' : '';

    return MqCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.pushNamed(context, '/course-details', arguments: c['id']),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail with type + price badges.
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AppNetworkImage(url: imgUrl, fit: BoxFit.cover, fallbackIcon: Icons.school_rounded),
                ),
              ),
              Positioned(
                top: 6, right: 6,
                child: MqBadge(label: 'حضوري', tone: MqBadgeTone.accent, solid: true),
              ),
              Positioned(
                bottom: 6, left: 6,
                child: MqBadge(
                  label: isFree ? 'مجاني' : '${_money.format(_priceOf(c))} د.ع',
                  tone: isFree ? MqBadgeTone.success : MqBadgeTone.orange,
                  solid: true,
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(MqSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['course_name']?.toString() ?? 'دورة بدون اسم',
                      style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subject.isNotEmpty || grade.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [subject, grade].where((e) => e.isNotEmpty).join(' · '),
                      style: context.text.labelSmall?.copyWith(color: m.accent),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (teacher.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.person_outline_rounded, size: 13, color: m.ink3),
                      MqSpacing.gapXxs,
                      Expanded(child: Text(teacher, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                  const Spacer(),
                  Row(children: [
                    if (distStr.isNotEmpty) ...[
                      Icon(Icons.location_on_outlined, size: 12, color: m.ink3),
                      MqSpacing.gapXxs,
                      Text(distStr, style: context.text.labelSmall),
                    ],
                    if (seats > 0) ...[
                      if (distStr.isNotEmpty) MqSpacing.gapSm,
                      Icon(Icons.event_seat_outlined, size: 12, color: m.ink3),
                      MqSpacing.gapXxs,
                      Text('$seats مقعد', style: context.text.labelSmall),
                    ],
                    const Spacer(),
                    Icon(Icons.chevron_left_rounded, size: 18, color: m.accent),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── states ──────────────────────────────────────────────────────────────────

  Widget _empty(BuildContext context) {
    final m = context.mq;
    final filtering = _query.isNotEmpty || _filter != 'all';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(child: Column(children: [
          Container(
            padding: const EdgeInsets.all(MqSpacing.lg),
            decoration: BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
            child: Icon(Icons.school_rounded, size: 44, color: m.accent),
          ),
          MqSpacing.gapMd,
          Text(filtering ? 'لا توجد دورات مطابقة' : 'لا توجد دورات مقترحة حالياً', style: context.text.titleMedium),
          MqSpacing.gapXs,
          Text(filtering ? 'جرّب تعديل البحث أو الفلاتر.' : 'سيتم عرض الدورات المناسبة لمرحلتك قريباً.',
              textAlign: TextAlign.center, style: context.text.bodySmall),
        ])),
      ],
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
          Text(_error ?? 'حدث خطأ', textAlign: TextAlign.center, style: context.text.bodyMedium),
          MqSpacing.gapMd,
          MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: () => _fetchCourses()),
        ])),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.lg),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 252,
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
              const SizedBox(height: 10),
              Container(height: 10, width: 110, color: m.fill2),
            ]),
          ),
        ]),
      ),
    );
  }
}
