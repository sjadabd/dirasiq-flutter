// Student → Browse video courses (MulhimIQ design-system pass).
//
// Public catalog surface — the backend hard-codes the approved + public
// filter so the catalog is the curated set admins signed off on. Cards link
// into the detail screen which lists lessons + opens the protected player.
//
// The pagination / infinite-scroll / search logic is UNCHANGED; only the
// presentation was restyled. The catalog response carries no per-student
// progress / owned / teacher data, so progress %, "continue watching", and
// the قيد المشاهدة / مكتملة progress filters are intentionally NOT rendered
// here (they live on the design-system Student Home "continue watching" rail,
// which is backed by the my-library endpoint). The supported axis on this
// catalog is free vs paid, surfaced as filter chips.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/api_service.dart';
import '../../../core/utils/money.dart';
import '../../../shared/design_system/design_system.dart';
import '../../../shared/widgets/app_network_image.dart';
import 'student_video_course_detail_screen.dart';

class StudentVideoCoursesScreen extends StatefulWidget {
  const StudentVideoCoursesScreen({super.key});

  @override
  State<StudentVideoCoursesScreen> createState() => _StudentVideoCoursesScreenState();
}

class _StudentVideoCoursesScreenState extends State<StudentVideoCoursesScreen> {
  final _api = ApiService();
  final _scroll = ScrollController();
  final _searchCtl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const _limit = 20;
  String _error = '';

  String _query = '';
  String _filter = 'all'; // all | free | paid

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _items = [];
        _page = 1;
        _hasMore = true;
        _error = '';
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final res = await _api.fetchPublicVideoCourses(page: _page, limit: _limit);
      final list = res['data'];
      final pageItems = (list is List)
          ? list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
          : <Map<String, dynamic>>[];
      final pagination = (res['meta'] is Map) ? Map<String, dynamic>.from(res['meta']['pagination'] ?? {}) : {};
      final total = (pagination['total'] is num) ? (pagination['total'] as num).toInt() : pageItems.length;
      setState(() {
        _items = [..._items, ...pageItems];
        _hasMore = _items.length < total && pageItems.isNotEmpty;
        if (_hasMore) _page += 1;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الدورات');
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  bool _isFree(Map<String, dynamic> c) =>
      c['isFree'] == true || c['is_free'] == true || c['price'] == 0;

  List<Map<String, dynamic>> get _visible {
    Iterable<Map<String, dynamic>> out = _items;
    if (_filter == 'free') out = out.where(_isFree);
    if (_filter == 'paid') out = out.where((c) => !_isFree(c));
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((c) {
        final t = (c['title'] ?? '').toString().toLowerCase();
        final s = (c['subject'] ?? '').toString().toLowerCase();
        final st = (c['teachingStage'] ?? '').toString().toLowerCase();
        return t.contains(q) || s.contains(q) || st.contains(q);
      });
    }
    return out.toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.mq.page,
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('الدورات المرئية'),
                  Text('تصفّح الدورات المسجّلة', style: context.text.bodySmall),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(96),
                child: _searchAndFilters(context),
              ),
            ),
            body: _loading
                ? _skeleton(context)
                : _error.isNotEmpty
                    ? _errorView(context)
                    : RefreshIndicator(
                        onRefresh: () => _fetch(reset: true),
                        child: _visible.isEmpty ? _empty(context) : _grid(context),
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
            controller: _searchCtl,
            onChanged: (v) => setState(() => _query = v),
            style: context.text.bodyMedium,
            decoration: InputDecoration(
              hintText: 'ابحث في الدورات…',
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
                      onPressed: () { _searchCtl.clear(); setState(() => _query = ''); },
                    ),
            ),
          ),
          MqSpacing.gapSm,
          Row(children: [
            _chip(context, 'all', 'الكل'),
            const SizedBox(width: MqSpacing.xs),
            _chip(context, 'free', 'المجانية'),
            const SizedBox(width: MqSpacing.xs),
            _chip(context, 'paid', 'المدفوعة'),
          ]),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String key, String label) {
    return MqChip(label: label, selected: _filter == key, onTap: () => setState(() => _filter = key));
  }

  Widget _grid(BuildContext context) {
    final items = _visible;
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.xxxl),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 244,
        crossAxisSpacing: MqSpacing.sm,
        mainAxisSpacing: MqSpacing.sm,
      ),
      itemCount: items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        final c = items[i];
        return _VideoCatalogCard(
          course: c,
          isFree: _isFree(c),
          onTap: () => Get.to(() => StudentVideoCourseDetailScreen(courseId: c['id'].toString())),
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(child: Column(children: [
          Container(
            padding: const EdgeInsets.all(MqSpacing.lg),
            decoration: BoxDecoration(color: m.accentSoft, shape: BoxShape.circle),
            child: Icon(Icons.video_library_outlined, size: 44, color: m.accent),
          ),
          MqSpacing.gapMd,
          Text('لا توجد دورات مطابقة', style: context.text.titleMedium),
          MqSpacing.gapXs,
          Text('جرّب تعديل البحث أو الفلاتر.', style: context.text.bodySmall),
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
          Text(_error, textAlign: TextAlign.center, style: context.text.bodyMedium),
          MqSpacing.gapMd,
          MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: () => _fetch(reset: true)),
        ])),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 244,
        crossAxisSpacing: MqSpacing.sm,
        mainAxisSpacing: MqSpacing.sm,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => MqCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(color: m.fill2),
          ),
          Padding(
            padding: const EdgeInsets.all(MqSpacing.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 12, width: double.infinity, color: m.fill2),
              const SizedBox(height: 6),
              Container(height: 10, width: 90, color: m.fill2),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _VideoCatalogCard extends StatelessWidget {
  const _VideoCatalogCard({required this.course, required this.isFree, required this.onTap});
  final Map<String, dynamic> course;
  final bool isFree;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = context.mq;
    return MqCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: course['coverImage']?.toString() ?? '',
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.movie_outlined,
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.12)),
                  const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 30)),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: MqBadge(
                      label: isFree ? 'مجاني' : '${fmtMoney(course['price'])} د.ع',
                      tone: isFree ? MqBadgeTone.success : MqBadgeTone.orange,
                      solid: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(MqSpacing.sm, MqSpacing.sm, MqSpacing.sm, MqSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course['title']?.toString() ?? '',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                  const SizedBox(height: 4),
                  Text('${course['subject'] ?? '—'} · ${course['teachingStage'] ?? '—'}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall),
                  const Spacer(),
                  Row(children: [
                    Icon(Icons.play_circle_outline, size: 14, color: m.accent),
                    MqSpacing.gapXxs,
                    Text('شاهد الآن',
                        style: context.text.labelMedium?.copyWith(color: m.accent, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
