// Student unified search — MulhimIQ design-system pass.
//
// Backed entirely by existing endpoints (no backend change):
//   • teachers + physical courses → ApiService.searchStudentUnified (free text)
//   • news                        → ApiService.fetchLatestNews(search:)  (free text)
//   • video courses               → ApiService.fetchPublicVideoCourses + client-side
//                                    title/teacher filter (no free-text VOD endpoint)
//
// Every field is probed defensively and only rendered when the backend
// actually provides it (rating, subject, price, stage, start date, image).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';

enum _Filter { all, teachers, physical, video, news }

class StudentUnifiedSearchScreen extends StatefulWidget {
  final String? initialQuery;
  const StudentUnifiedSearchScreen({super.key, this.initialQuery});

  @override
  State<StudentUnifiedSearchScreen> createState() =>
      _StudentUnifiedSearchScreenState();
}

class _StudentUnifiedSearchScreenState extends State<StudentUnifiedSearchScreen> {
  static const _recentKey = 'student_recent_searches';

  final _api = ApiService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  String _query = '';
  _Filter _filter = _Filter.all;
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _news = [];

  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      final q = widget.initialQuery?.trim() ?? '';
      if (q.isNotEmpty) {
        _controller.text = q;
        _runSearch(q);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── recent searches (local only) ────────────────────────────────────────────

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentKey) ?? [];
      if (mounted) setState(() => _recent = list);
    } catch (_) {}
  }

  Future<void> _saveRecent(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    final next = [query, ..._recent.where((e) => e != query)].take(8).toList();
    setState(() => _recent = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentKey, next);
    } catch (_) {}
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentKey);
    } catch (_) {}
  }

  // ── search ──────────────────────────────────────────────────────────────────

  void _onChanged(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      setState(() {
        _query = v;
        _teachers = [];
        _courses = [];
        _videos = [];
        _news = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(v));
  }

  Future<void> _runSearch(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
    });

    final wantTeachersOrCourses =
        _filter == _Filter.all || _filter == _Filter.teachers || _filter == _Filter.physical;
    final wantVideo = _filter == _Filter.all || _filter == _Filter.video;
    final wantNews = _filter == _Filter.all || _filter == _Filter.news;

    var teachers = <Map<String, dynamic>>[];
    var courses = <Map<String, dynamic>>[];
    var videos = <Map<String, dynamic>>[];
    var news = <Map<String, dynamic>>[];
    var anyOk = false;

    await Future.wait([
      if (wantTeachersOrCourses)
        _safe(() async {
          final resp = await _api.searchStudentUnified(q: query, page: 1, limit: 15, maxDistance: 8);
          final data = (resp['data'] ?? resp) as Map;
          teachers = _listOf(data['teachers']);
          courses = _listOf(data['courses']);
          anyOk = true;
        }),
      if (wantVideo)
        _safe(() async {
          final resp = await _api.fetchPublicVideoCourses(page: 1, limit: 50);
          final raw = resp['data'];
          final all = raw is List
              ? _listOf(raw)
              : (raw is Map ? _listOf((raw)['data'] ?? (raw)['courses'] ?? (raw)['items']) : <Map<String, dynamic>>[]);
          final ql = query.toLowerCase();
          videos = all.where((c) {
            final title = (c['title'] ?? c['name'] ?? '').toString().toLowerCase();
            final t = (c['teacher']?['name'] ?? c['teacherName'] ?? c['teacher_name'] ?? '').toString().toLowerCase();
            return title.contains(ql) || t.contains(ql);
          }).toList();
          anyOk = true;
        }),
      if (wantNews)
        _safe(() async {
          news = await _api.fetchLatestNews(page: 1, limit: 10, search: query);
          anyOk = true;
        }),
    ]);

    if (!mounted) return;
    setState(() {
      _teachers = teachers;
      _courses = courses;
      _videos = videos;
      _news = news;
      _loading = false;
      _error = anyOk ? null : 'تعذّر تنفيذ البحث';
    });
    if (anyOk) _saveRecent(query);
  }

  Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {}
  }

  List<Map<String, dynamic>> _listOf(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

  void _submitQuery(String q) {
    _debounce?.cancel();
    _runSearch(q);
  }

  void _setFilter(_Filter f) {
    setState(() => _filter = f);
    if (_query.trim().length >= 2) _runSearch(_query);
  }

  // ── build ─────────────────────────────────────────────────────────────────

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
            appBar: AppBar(title: const Text('البحث')),
            body: Column(
              children: [
                _searchField(context),
                _filterRow(context),
                Expanded(child: _body(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final mq = context.mq;
    return Container(
      color: mq.page,
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.sm),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        onChanged: _onChanged,
        onSubmitted: _submitQuery,
        decoration: InputDecoration(
          hintText: 'ابحث عن أستاذ، دورة، أو خبر…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _controller.clear();
                    _onChanged('');
                  },
                ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _filterRow(BuildContext context) {
    const items = [
      (_Filter.all, 'الكل', Icons.apps_rounded),
      (_Filter.teachers, 'الأساتذة', Icons.cast_for_education_outlined),
      (_Filter.physical, 'الدورات الحضورية', Icons.school_outlined),
      (_Filter.video, 'الدورات المرئية', Icons.play_circle_outline_rounded),
      (_Filter.news, 'الأخبار', Icons.campaign_outlined),
    ];
    return Container(
      decoration: BoxDecoration(
        color: context.mq.page,
        border: Border(bottom: BorderSide(color: context.mq.line)),
      ),
      padding: const EdgeInsets.only(bottom: MqSpacing.sm),
      child: SizedBox(
        height: MqSize.chipHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: MqSpacing.lg),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.xs),
          itemBuilder: (_, i) {
            final (f, label, icon) = items[i];
            return MqChip(label: label, icon: icon, selected: _filter == f, onTap: () => _setFilter(f));
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_query.trim().length < 2) return _initialView(context);
    if (_loading) return _Skeleton();
    if (_error != null) return _error_(context);

    final showTeachers = _filter == _Filter.all || _filter == _Filter.teachers;
    final showPhysical = _filter == _Filter.all || _filter == _Filter.physical;
    final showVideo = _filter == _Filter.all || _filter == _Filter.video;
    final showNews = _filter == _Filter.all || _filter == _Filter.news;

    final tEmpty = !showTeachers || _teachers.isEmpty;
    final pEmpty = !showPhysical || _courses.isEmpty;
    final vEmpty = !showVideo || _videos.isEmpty;
    final nEmpty = !showNews || _news.isEmpty;
    if (tEmpty && pEmpty && vEmpty && nEmpty) return _empty(context);

    final children = <Widget>[];
    void section(String title, List<Map<String, dynamic>> items, Widget Function(Map<String, dynamic>) card) {
      if (items.isEmpty) return;
      children.add(_SectionHeader(title: title, count: items.length));
      for (final m in items) {
        children.add(Padding(padding: const EdgeInsets.only(bottom: MqSpacing.sm), child: card(m)));
      }
      children.add(const SizedBox(height: MqSpacing.sm));
    }

    if (showTeachers) section('الأساتذة', _teachers, (m) => _TeacherCard(m));
    if (showPhysical) section('الدورات الحضورية', _courses, (m) => _PhysicalCourseCard(m));
    if (showVideo) section('الدورات المرئية', _videos, (m) => _VideoCourseCard(m));
    if (showNews) section('الأخبار', _news, (m) => _NewsCard(m));

    return RefreshIndicator(
      onRefresh: () => _runSearch(_query),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.xxxl),
        children: children,
      ),
    );
  }

  Widget _initialView(BuildContext context) {
    final mq = context.mq;
    return ListView(
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.xxxl),
      children: [
        if (_recent.isNotEmpty) ...[
          Row(
            children: [
              Text('عمليات بحث سابقة', style: context.text.titleSmall),
              const Spacer(),
              MqButton.text(label: 'مسح', size: MqButtonSize.small, onPressed: _clearRecent),
            ],
          ),
          MqSpacing.gapSm,
          Wrap(
            spacing: MqSpacing.xs,
            runSpacing: MqSpacing.xs,
            children: [
              for (final q in _recent)
                MqChip(
                  label: q,
                  icon: Icons.history_rounded,
                  onTap: () {
                    _controller.text = q;
                    _runSearch(q);
                  },
                ),
            ],
          ),
          MqSpacing.gapXl,
        ],
        const SizedBox(height: MqSpacing.xxl),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(MqSpacing.lg),
                decoration: BoxDecoration(color: mq.accentSoft, shape: BoxShape.circle),
                child: Icon(Icons.search_rounded, size: 44, color: mq.accent),
              ),
              MqSpacing.gapMd,
              Text('ابدأ البحث', style: context.text.titleMedium),
              MqSpacing.gapXs,
              Text('اكتب اسم أستاذ أو دورة أو خبر للعثور عليه.',
                  textAlign: TextAlign.center, style: context.text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final mq = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(MqSpacing.lg),
                decoration: BoxDecoration(color: mq.fill2, shape: BoxShape.circle),
                child: Icon(Icons.search_off_rounded, size: 44, color: mq.ink3),
              ),
              MqSpacing.gapMd,
              Text('لا توجد نتائج', style: context.text.titleMedium),
              MqSpacing.gapXs,
              Text('لم نعثر على نتائج لـ "$_query". جرّب كلمة أخرى.',
                  textAlign: TextAlign.center, style: context.text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _error_(BuildContext context) {
    final mq = context.mq;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MqSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 44, color: mq.error),
            MqSpacing.gapMd,
            Text(_error ?? 'حدث خطأ', textAlign: TextAlign.center, style: context.text.bodyMedium),
            MqSpacing.gapMd,
            MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: () => _runSearch(_query)),
          ],
        ),
      ),
    );
  }
}

// ── helpers ───────────────────────────────────────────────────────────────────

String? _resolveUrl(dynamic path) {
  final p = path?.toString().trim() ?? '';
  if (p.isEmpty) return null;
  if (p.startsWith('http://') || p.startsWith('https://') || p.startsWith('data:')) return p;
  final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r'/+$'), '');
  return p.startsWith('/') ? '$base$p' : '$base/$p';
}

T? _first<T>(Map m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null && v.toString().trim().isNotEmpty) return v as T;
  }
  return null;
}

String _moneyOrFree(dynamic price, {String currency = 'د.ع'}) {
  final n = price is num ? price : num.tryParse('${price ?? ''}');
  if (n == null) return '';
  if (n <= 0) return 'مجاني';
  final s = n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
  return '$s $currency';
}

// ── result cards ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    return Padding(
      padding: const EdgeInsets.only(bottom: MqSpacing.sm, top: MqSpacing.xs),
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: mq.accent, borderRadius: MqRadius.brPill)),
          MqSpacing.gapSm,
          Text(title, style: context.text.titleSmall),
          MqSpacing.gapXs,
          MqBadge(label: '$count', tone: MqBadgeTone.neutral),
        ],
      ),
    );
  }
}

class _RoundImage extends StatelessWidget {
  const _RoundImage({required this.url, required this.fallbackText, this.icon});
  final String? url;
  final String fallbackText;
  final IconData? icon;
  static const double size = 48;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final fallback = Container(
      color: mq.accentSoft,
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: mq.accent, size: size * 0.45)
          : Text(fallbackText.isNotEmpty ? fallbackText.characters.first : '؟',
              style: context.text.titleMedium?.copyWith(color: mq.accent)),
    );
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null ? fallback : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard(this.t);
  final Map<String, dynamic> t;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final name = _first<Object>(t, ['name', 'fullName'])?.toString() ?? '';
    final subject = _first<Object>(t, ['subject', 'subjectName', 'subject_name'])?.toString();
    final address = _first<Object>(t, ['address', 'city'])?.toString();
    final ratingRaw = _first<Object>(t, ['rating', 'avgRating', 'average_rating']);
    final rating = ratingRaw is num ? ratingRaw.toDouble() : double.tryParse('${ratingRaw ?? ''}');
    final distRaw = _first<Object>(t, ['distance']);
    final dist = distRaw is num ? distRaw.toDouble() : double.tryParse('${distRaw ?? ''}');
    final img = _resolveUrl(_first<Object>(t, ['profileImagePath', 'profile_image_path', 'image', 'avatar']));
    final id = (t['id'] ?? '').toString();

    return MqCard(
      onTap: id.isEmpty ? null : () => Get.toNamed('/teacher-details', arguments: id),
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(
        children: [
          _RoundImage(url: img, fallbackText: name, icon: Icons.person),
          MqSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subject != null) ...[
                  const SizedBox(height: 2),
                  Text(subject, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ] else if (address != null) ...[
                  const SizedBox(height: 2),
                  Text(address, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (rating != null || dist != null) ...[
                  MqSpacing.gapXs,
                  Row(
                    children: [
                      if (rating != null) ...[
                        Icon(Icons.star_rounded, size: 14, color: mq.orange),
                        MqSpacing.gapXxs,
                        Text(rating.toStringAsFixed(1), style: context.text.labelSmall?.copyWith(color: mq.ink)),
                        MqSpacing.gapSm,
                      ],
                      if (dist != null)
                        MqBadge(label: '${dist.toStringAsFixed(1)} كم', tone: MqBadgeTone.neutral, icon: Icons.place_outlined),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: mq.ink3),
        ],
      ),
    );
  }
}

class _PhysicalCourseCard extends StatelessWidget {
  const _PhysicalCourseCard(this.c);
  final Map<String, dynamic> c;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final name = _first<Object>(c, ['courseName', 'course_name', 'name', 'title'])?.toString() ?? '';
    final teacher = (c['teacher'] is Map ? c['teacher']['name'] : null)?.toString() ??
        _first<Object>(c, ['teacher_name', 'teacherName'])?.toString();
    final stage = _first<Object>(c, ['gradeName', 'grade_name', 'grade', 'stage'])?.toString();
    final price = _first<Object>(c, ['price', 'fee', 'amount']);
    final startRaw = _first<Object>(c, ['startDate', 'start_date']);
    final start = startRaw == null ? null : DateTime.tryParse(startRaw.toString());
    final id = (c['id'] ?? '').toString();

    return MqCard(
      onTap: id.isEmpty ? null : () => Get.toNamed('/course-details', arguments: id),
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: mq.accentSoft, borderRadius: MqRadius.brMd),
            child: Icon(Icons.menu_book_rounded, color: mq.accent, size: MqSize.iconMd),
          ),
          MqSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (teacher != null && teacher.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(teacher, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                MqSpacing.gapXs,
                Wrap(
                  spacing: MqSpacing.xs,
                  runSpacing: MqSpacing.xxs,
                  children: [
                    if (stage != null) MqBadge(label: stage, tone: MqBadgeTone.neutral),
                    if (price != null && _moneyOrFree(price).isNotEmpty)
                      MqBadge(label: _moneyOrFree(price), tone: MqBadgeTone.accent),
                    if (start != null)
                      MqBadge(label: 'تبدأ ${DateFormat('dd/MM').format(start)}', tone: MqBadgeTone.orange, icon: Icons.event_outlined),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: mq.ink3),
        ],
      ),
    );
  }
}

class _VideoCourseCard extends StatelessWidget {
  const _VideoCourseCard(this.c);
  final Map<String, dynamic> c;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final title = _first<Object>(c, ['title', 'name', 'courseName', 'course_name'])?.toString() ?? '';
    final teacher = (c['teacher'] is Map ? c['teacher']['name'] : null)?.toString() ??
        _first<Object>(c, ['teacherName', 'teacher_name'])?.toString();
    final thumb = _resolveUrl(_first<Object>(c, ['thumbnail', 'thumbnailUrl', 'thumbnail_url', 'cover', 'image', 'poster']));
    final price = _first<Object>(c, ['price', 'amount']);
    final id = _first<Object>(c, ['id', '_id', 'videoCourseId'])?.toString() ?? '';

    return MqCard(
      onTap: id.isEmpty ? null : () => Get.toNamed('/student/video-course-details', arguments: id),
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: MqRadius.brMd,
            child: SizedBox(
              width: 64, height: 48,
              child: thumb == null
                  ? Container(color: mq.fill2, child: Icon(Icons.play_circle_outline_rounded, color: mq.ink3))
                  : Image.network(thumb, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: mq.fill2, child: Icon(Icons.play_circle_outline_rounded, color: mq.ink3))),
            ),
          ),
          MqSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (teacher != null && teacher.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(teacher, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (price != null && _moneyOrFree(price).isNotEmpty) ...[
                  MqSpacing.gapXs,
                  MqBadge(label: _moneyOrFree(price), tone: MqBadgeTone.accent, solid: true),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: mq.ink3),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard(this.n);
  final Map<String, dynamic> n;
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    final title = _first<Object>(n, ['title', 'headline', 'name'])?.toString() ?? '';
    final desc = _first<Object>(n, ['description', 'summary', 'content', 'body'])?.toString();
    final img = _resolveUrl(_first<Object>(n, ['imageUrl', 'image', 'image_url', 'cover', 'thumbnail']));
    final dateRaw = _first<Object>(n, ['publishedAt', 'published_at', 'createdAt', 'created_at', 'date']);
    final date = dateRaw == null ? null : DateTime.tryParse(dateRaw.toString());

    // News has no detail route → display-only card (no onTap).
    return MqCard(
      padding: const EdgeInsets.all(MqSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: MqRadius.brMd,
            child: SizedBox(
              width: 56, height: 56,
              child: img == null
                  ? Container(color: mq.orangeSoft, child: Icon(Icons.campaign_outlined, color: mq.orangeDeep))
                  : Image.network(img, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: mq.orangeSoft, child: Icon(Icons.campaign_outlined, color: mq.orangeDeep))),
            ),
          ),
          MqSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (desc != null) ...[
                  const SizedBox(height: 2),
                  Text(desc, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (date != null) ...[
                  MqSpacing.gapXs,
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: mq.ink3),
                      MqSpacing.gapXxs,
                      Text(DateFormat('dd/MM/yyyy').format(date), style: context.text.labelSmall),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mq = context.mq;
    Widget bar(double w, double h) =>
        Container(width: w, height: h, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brSm));
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.md, MqSpacing.lg, MqSpacing.lg),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
      itemBuilder: (_, _) => MqCard(
        padding: const EdgeInsets.all(MqSpacing.md),
        child: Row(
          children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brMd)),
            MqSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [bar(140, 12), const SizedBox(height: 8), bar(200, 10)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
