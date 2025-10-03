import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:dirasiq/features/teachers/screens/teacher_details_screen.dart';

class SuggestedTeachersScreen extends StatefulWidget {
  const SuggestedTeachersScreen({super.key});

  @override
  State<SuggestedTeachersScreen> createState() =>
      _SuggestedTeachersScreenState();
}

class _SuggestedTeachersScreenState extends State<SuggestedTeachersScreen> {
  final _api = ApiService();
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController(text: "");

  bool _loading = false;
  bool _initialLoaded = false;
  int _page = 1;
  final int _limit = 10;
  final double _maxDistance = 10.0;
  String? _search;
  List<Map<String, dynamic>> _items = [];
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (reset) {
        _page = 1;
        _items = [];
        _hasMore = true;
      }
      final res = await _api.fetchSuggestedTeachers(
        page: _page,
        limit: _limit,
        maxDistance: _maxDistance,
        search: _search,
      );
      final newItems = List<Map<String, dynamic>>.from(res['items'] ?? []);
      setState(() {
        _items.addAll(newItems);
        _hasMore = newItems.length >= _limit;
        _page++;
        _initialLoaded = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 120) {
      _load();
    }
  }

  Future<void> _onRefresh() async {
    await _load(reset: true);
  }

  String _fullImageUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return '';
    if (pathOrUrl.startsWith('http')) return pathOrUrl;
    if (pathOrUrl.startsWith('/'))
      return '${AppConfig.serverBaseUrl}$pathOrUrl';
    return pathOrUrl;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('المعلمين المقترحين')),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                _search = _searchCtrl.text.trim().isEmpty
                    ? null
                    : _searchCtrl.text.trim();
                _load(reset: true);
              },
              decoration: InputDecoration(
                hintText: 'ابحث عن معلم أو مادة أو كورس...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search = null;
                          _load(reset: true);
                        },
                      ),
                filled: true,
                fillColor: cs.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: !_initialLoaded && _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      controller: _scrollCtrl,
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final t = _items[index];
                        final name = (t['name'] ?? t['teacher_name'] ?? '')
                            .toString();
                        final subject =
                            (t['subject_name'] ?? t['subject'] ?? '')
                                .toString();
                        final imgPath =
                            (t['profileImagePath'] ??
                                    t['teacher_profile_image_path'] ??
                                    t['avatar'] ??
                                    '')
                                .toString();
                        final imgUrl = _fullImageUrl(imgPath);
                        final distance = t['distance'];
                        final distStr = distance is num
                            ? "${distance.toStringAsFixed(1)} كم"
                            : '';

                        return Material(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              final id = (t['id'] ?? t['teacher_id'] ?? t['teacherId'] ?? '').toString();
                              if (id.isNotEmpty) {
                                Get.to(() => TeacherDetailsScreen(teacherId: id));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('هوية المعلم غير متوفرة')),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      color: cs.surfaceVariant,
                                      child: imgUrl.isEmpty
                                          ? Icon(
                                              Icons.person,
                                              color: cs.onSurfaceVariant,
                                            )
                                          : Image.network(
                                              imgUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(
                                                    Icons.person,
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.book_outlined,
                                              size: 14,
                                              color: cs.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                subject,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (distStr.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 14,
                                                color: cs.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                distStr,
                                                style: TextStyle(
                                                  color: cs.primary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
