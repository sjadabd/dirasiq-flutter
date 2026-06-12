// Student → My courses / enrollments (MulhimIQ design-system pass). RootShell
// tab "دوراتي" + standalone route /enrollments.
//
// Backed by ApiService.fetchStudentEnrollments → GET /student/enrollments,
// which returns ONLY the student's CONFIRMED enrollments (physical courses) for
// the active academic year, paginated. The fetch, pagination, and the Course
// Hub navigation are UNCHANGED. Each item carries:
//   course{ id, name, images, description, startDate, endDate, price,
//           seatsCount }, teacher{ id, name }, status, studyYear, bookingDate.
//
// It does NOT carry subject, grade/stage, attendance, progress, next-lecture,
// or any video-course data — so those fields, and the مرئية / حضورية filters,
// are intentionally not rendered (no fake data). Every enrollment here is a
// physical course; active-vs-ended is derived honestly from endDate.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'package:mulhimiq/shared/widgets/app_network_image.dart';

class EnrollmentsScreen extends StatefulWidget {
  const EnrollmentsScreen({super.key});

  @override
  State<EnrollmentsScreen> createState() => _EnrollmentsScreenState();
}

class _EnrollmentsScreenState extends State<EnrollmentsScreen> {
  final _api = ApiService();
  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;
  List<Map<String, dynamic>> _items = [];

  String _query = '';
  String _filter = 'all'; // all | active | ended

  @override
  void initState() {
    super.initState();
    _fetch(refresh: true);
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
      if (!_loadingMore && _hasMore && _query.isEmpty) _fetch();
    }
  }

  Future<void> _fetch({bool refresh = false}) async {
    try {
      if (refresh) {
        setState(() {
          _loading = true;
          _error = null;
          _page = 1;
          _items.clear();
          _hasMore = true;
        });
      } else {
        setState(() => _loadingMore = true);
      }

      final res = await _api.fetchStudentEnrollments(page: _page, limit: 10);
      final data = List<Map<String, dynamic>>.from(res['data'] ?? []);
      final pagination = Map<String, dynamic>.from(res['pagination'] ?? res['meta']?['pagination'] ?? {});
      final total = pagination['total'] ?? data.length;

      setState(() {
        if (refresh) {
          _items = data;
        } else {
          _items.addAll(data);
        }
        _loading = false;
        _loadingMore = false;
        _hasMore = _items.length < total;
        if (_hasMore) _page++;
      });
    } catch (_) {
      setState(() {
        _error = 'تعذّر تحميل دوراتك';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  // ─── navigation (preserved) ─────────────────────────────────────────────────

  void _openHub(Map<String, dynamic> item) {
    final course = Map<String, dynamic>.from(item['course'] ?? {});
    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;
    final route = AppConfig.useNewCourseHub ? '/course-hub' : '/enrollment-actions';
    Get.toNamed(route, arguments: {
      'courseId': courseId,
      'courseName': course['name']?.toString(),
      'teacherId': (item['teacher']?['id'])?.toString(),
    });
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  String _fullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return '${AppConfig.serverBaseUrl}$path';
    return '${AppConfig.serverBaseUrl}/$path';
  }

  String _imageOf(Map<String, dynamic> course) {
    final imgs = course['images'] ?? course['course_images'];
    if (imgs is List && imgs.isNotEmpty) return _fullImageUrl(imgs.first.toString());
    return '';
  }

  DateTime? _date(dynamic v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _fmtDate(dynamic v) {
    final d = _date(v);
    return d == null ? '' : DateFormat('yyyy/MM/dd').format(d);
  }

  bool _isEnded(Map<String, dynamic> course) {
    final end = _date(course['endDate']);
    return end != null && end.isBefore(DateTime.now());
  }

  List<Map<String, dynamic>> get _visible {
    Iterable<Map<String, dynamic>> out = _items;
    if (_filter == 'active') out = out.where((i) => !_isEnded(Map<String, dynamic>.from(i['course'] ?? {})));
    if (_filter == 'ended') out = out.where((i) => _isEnded(Map<String, dynamic>.from(i['course'] ?? {})));
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((i) {
        final c = Map<String, dynamic>.from(i['course'] ?? {});
        final t = Map<String, dynamic>.from(i['teacher'] ?? {});
        final name = (c['name'] ?? '').toString().toLowerCase();
        final teacher = (t['name'] ?? '').toString().toLowerCase();
        return name.contains(q) || teacher.contains(q);
      });
    }
    return out.toList();
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
                automaticallyImplyLeading: Navigator.of(context).canPop(),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('دوراتي'),
                    Text('الدورات التي انضممت إليها', style: context.text.bodySmall),
                  ],
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(96),
                  child: _searchAndFilters(context),
                ),
              ),
              body: RefreshIndicator(onRefresh: () => _fetch(refresh: true), child: _body(context)),
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
              hintText: 'ابحث في دوراتك…',
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
            _chip(context, 'active', 'نشطة'),
            const SizedBox(width: MqSpacing.xs),
            _chip(context, 'ended', 'منتهية'),
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
    if (_error != null && _items.isEmpty) return _errorView(context);
    if (_items.isEmpty) return _empty(context);
    final items = _visible;
    if (items.isEmpty) return _noMatch(context);

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.xxxl + MqSpacing.xl),
      itemCount: items.length + (_loadingMore && _query.isEmpty ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.all(MqSpacing.md),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        return _courseCard(context, items[index]);
      },
    );
  }

  Widget _courseCard(BuildContext context, Map<String, dynamic> item) {
    final m = context.mq;
    final course = Map<String, dynamic>.from(item['course'] ?? {});
    final teacher = Map<String, dynamic>.from(item['teacher'] ?? {});
    final name = (course['name'] ?? 'دورة بدون اسم').toString();
    final teacherName = (teacher['name'] ?? '').toString();
    final imgUrl = _imageOf(course);
    final ended = _isEnded(course);
    final start = _fmtDate(course['startDate']);
    final end = _fmtDate(course['endDate']);

    return MqCard(
      padding: EdgeInsets.zero,
      onTap: () => _openHub(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                child: MqBadge(label: 'حضوري', tone: MqBadgeTone.accent, solid: true, icon: Icons.location_city_rounded),
              ),
              Positioned(
                top: 6, left: 6,
                child: MqBadge(
                  label: ended ? 'منتهية' : 'نشطة',
                  tone: ended ? MqBadgeTone.neutral : MqBadgeTone.success,
                  solid: true,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(MqSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (teacherName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.person_outline_rounded, size: 13, color: m.ink3),
                    MqSpacing.gapXxs,
                    Expanded(child: Text(teacherName, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                if (start.isNotEmpty || end.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.event_outlined, size: 13, color: m.ink3),
                    MqSpacing.gapXxs,
                    Text(
                      start.isNotEmpty && end.isNotEmpty ? '$start - $end' : (start.isNotEmpty ? start : end),
                      style: context.text.labelSmall,
                    ),
                  ]),
                ],
                MqSpacing.gapSm,
                MqButton(
                  label: 'بيئة الدورة',
                  icon: Icons.dashboard_customize_outlined,
                  size: MqButtonSize.small,
                  onPressed: () => _openHub(item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── states ─────────────────────────────────────────────────────────────────

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
            child: Icon(Icons.school_rounded, size: 44, color: m.accent),
          ),
          MqSpacing.gapMd,
          Text('لم تنضم لأي دورة بعد', style: context.text.titleMedium),
          MqSpacing.gapXs,
          Text('تصفّح الدورات المتاحة وانضم إلى ما يناسبك.', textAlign: TextAlign.center, style: context.text.bodySmall),
          MqSpacing.gapLg,
          MqButton(
            label: 'تصفّح الدورات',
            icon: Icons.search_rounded,
            expand: false,
            onPressed: () => Get.toNamed('/suggested-courses'),
          ),
        ])),
      ],
    );
  }

  Widget _noMatch(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(child: Column(children: [
          Icon(Icons.filter_alt_off_outlined, size: 44, color: m.ink3),
          MqSpacing.gapMd,
          Text('لا توجد دورات مطابقة', style: context.text.bodyMedium),
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
          Text(_error ?? 'حدث خطأ', textAlign: TextAlign.center, style: context.text.bodyMedium),
          MqSpacing.gapMd,
          MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: () => _fetch(refresh: true)),
        ])),
      ],
    );
  }

  Widget _skeleton(BuildContext context) {
    final m = context.mq;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.lg),
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: MqSpacing.sm),
            child: MqCard(
              padding: EdgeInsets.zero,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AspectRatio(aspectRatio: 16 / 9, child: Container(color: m.fill2)),
                Padding(
                  padding: const EdgeInsets.all(MqSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 13, width: double.infinity, color: m.fill2),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 120, color: m.fill2),
                  ]),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
