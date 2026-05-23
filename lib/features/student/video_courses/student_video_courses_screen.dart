// Student → Browse video courses.
//
// Public surface — the backend hard-codes the approved + public filter so
// the catalog is the curated set that admins have signed off on. Cards
// link into the detail screen which shows lessons + opens the HLS player.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/api_service.dart';
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

  // Client-side search filter (the backend can also filter by subject /
  // teachingStage; for now we only ship a free-text title filter).
  String _query = '';

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

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _items;
    final q = _query.trim().toLowerCase();
    return _items.where((c) {
      final t = (c['title'] ?? '').toString().toLowerCase();
      final s = (c['subject'] ?? '').toString().toLowerCase();
      final st = (c['teachingStage'] ?? '').toString().toLowerCase();
      return t.contains(q) || s.contains(q) || st.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('الدورات المرئية'),
        backgroundColor: scheme.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'ابحث في الدورات…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () { _searchCtl.clear(); setState(() => _query = ''); },
                      ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error, style: TextStyle(color: scheme.error)),
                  const SizedBox(height: 8),
                  FilledButton.tonal(onPressed: () => _fetch(reset: true), child: const Text('إعادة المحاولة')),
                ]))
              : RefreshIndicator(
                  onRefresh: () => _fetch(reset: true),
                  child: _filtered.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Icon(Icons.video_library_outlined, size: 60, color: Colors.grey)),
                            SizedBox(height: 8),
                            Center(child: Text('لا توجد دورات مطابقة', style: TextStyle(color: Colors.grey))),
                          ],
                        )
                      : GridView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisExtent: 240,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _filtered.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i >= _filtered.length) {
                              return const Center(child: Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                              ));
                            }
                            final c = _filtered[i];
                            return _StudentCourseCard(
                              course: c,
                              onTap: () => Get.to(() => StudentVideoCourseDetailScreen(courseId: c['id'].toString())),
                            );
                          },
                        ),
                ),
    );
  }
}

class _StudentCourseCard extends StatelessWidget {
  const _StudentCourseCard({required this.course, required this.onTap});
  final Map<String, dynamic> course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFree = course['isFree'] == true;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: course['coverImage']?.toString() ?? '',
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.movie_outlined,
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isFree ? Colors.green : Colors.orange).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isFree ? 'مجاني' : '${course['price'] ?? 0} د.ع',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${course['subject'] ?? '—'} · ${course['teachingStage'] ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Row(children: [
                      Icon(Icons.play_circle_outline, size: 14, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text('شاهد الآن', style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
