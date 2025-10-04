import 'dart:ui';
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

class _SuggestedTeachersScreenState extends State<SuggestedTeachersScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

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
    _focusNode.dispose();
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
        _scrollCtrl.position.maxScrollExtent - 100) {}
  }

  Future<void> _onRefresh() async {
    await _load(reset: true);
  }

  String _fullImageUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return '';
    if (pathOrUrl.startsWith('http')) return pathOrUrl;
    if (pathOrUrl.startsWith('/')) {
      return '${AppConfig.serverBaseUrl}$pathOrUrl';
    }
    return pathOrUrl;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(
        context,
      ).unfocus(), // ✅ إخفاء المؤشر عند الضغط خارج الحقل
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          title: const Text('المعلمين المقترحين'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: cs.surface,
        ),
        body: SafeArea(
          bottom: true,
          top: true,
          child: Column(
            children: [
              // 🔍 مربع البحث
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                  onSubmitted: (_) {
                    _search = _searchCtrl.text.trim().isEmpty
                        ? null
                        : _searchCtrl.text.trim();
                    _load(reset: true);
                  },
                  decoration: InputDecoration(
                    hintText: 'ابحث عن معلم...',
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              _search = null;
                              _load(reset: true);
                            },
                          ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // 📜 قائمة المعلمين
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: !_initialLoaded && _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          controller: _scrollCtrl,
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                          itemBuilder: (context, index) {
                            if (index >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final t = _items[index];
                            final name =
                                (t['name'] ?? t['teacher_name'] ?? 'غير معروف')
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

                            final id =
                                (t['id'] ??
                                        t['teacher_id'] ??
                                        t['teacherId'] ??
                                        '')
                                    .toString();

                            final borderColor = isDark
                                ? cs.outlineVariant.withValues(alpha: 0.3)
                                : cs.primary.withValues(alpha: 0.25);

                            // ✅ حركة دخول متدرجة
                            final animationController = AnimationController(
                              vsync: this,
                              duration: const Duration(milliseconds: 500),
                            );
                            final animation =
                                Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animationController,
                                    curve: Curves.easeOutCubic,
                                  ),
                                );

                            Future.delayed(
                              Duration(milliseconds: 100 * index),
                              () => animationController.forward(),
                            );

                            return FadeTransition(
                              opacity: animationController,
                              child: SlideTransition(
                                position: animation,
                                child: Hero(
                                  tag: 'teacher_$id',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest
                                              .withValues(alpha: 0.8),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: borderColor,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          onTap: () {
                                            if (id.isNotEmpty) {
                                              Get.to(
                                                () => TeacherDetailsScreen(
                                                  teacherId: id,
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'هوية المعلم غير متوفرة',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Row(
                                              children: [
                                                // 👤 صورة المعلم
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(50),
                                                  child: Container(
                                                    width: 52,
                                                    height: 52,
                                                    color: cs
                                                        .surfaceContainerHighest,
                                                    child: imgUrl.isEmpty
                                                        ? Icon(
                                                            Icons
                                                                .person_rounded,
                                                            color: cs
                                                                .onSurfaceVariant,
                                                            size: 28,
                                                          )
                                                        : Image.network(
                                                            imgUrl,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (
                                                                  _,
                                                                  _,
                                                                  _,
                                                                ) => Icon(
                                                                  Icons
                                                                      .person_rounded,
                                                                  color: cs
                                                                      .onSurfaceVariant,
                                                                  size: 28,
                                                                ),
                                                          ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),

                                                // 📄 معلومات المعلم
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: cs.onSurface,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.book_outlined,
                                                            size: 12,
                                                            color: cs
                                                                .onSurfaceVariant,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              subject.isEmpty
                                                                  ? '—'
                                                                  : subject,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: cs
                                                                    .onSurfaceVariant,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (distStr
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .location_on_outlined,
                                                              size: 12,
                                                              color: cs.primary,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              distStr,
                                                              style: TextStyle(
                                                                color:
                                                                    cs.primary,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  size: 14,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
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
        ),
      ),
    );
  }
}
