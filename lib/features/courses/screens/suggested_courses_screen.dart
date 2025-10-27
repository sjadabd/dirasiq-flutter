import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';

class SuggestedCoursesScreen extends StatefulWidget {
  const SuggestedCoursesScreen({super.key});

  @override
  State<SuggestedCoursesScreen> createState() => _SuggestedCoursesScreenState();
}

class _SuggestedCoursesScreenState extends State<SuggestedCoursesScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) _fetchCourses(loadMore: true);
    }
  }

  Future<void> _fetchCourses({bool loadMore = false}) async {
    final api = ApiService();
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

      final res = await api.fetchSuggestedCourses(
        page: _page,
        limit: 8,
        maxDistance: 10.0,
      );

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
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: const GlobalAppBar(title: "الكورسات المقترحة", centerTitle: true),
      body: RefreshIndicator(
        notificationPredicate: (_) => true,
        displacement: 36,
        onRefresh: () => _fetchCourses(loadMore: false),
        color: AppColors.primary,
        child: _loading
            ? _buildLoading()
            : _error != null
            ? _buildError(theme)
            : _courses.isEmpty
            ? _buildEmpty(theme)
            : _buildGrid(theme, isDark),
      ),
    );
  }

  ScrollPhysics _refreshPhysics(BuildContext ctx) {
    final platform = Theme.of(ctx).platform;
    final parent = platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
        ? const BouncingScrollPhysics()
        : const ClampingScrollPhysics();
    return AlwaysScrollableScrollPhysics(parent: parent);
  }

  Widget _buildLoading() => ListView(
        physics: _refreshPhysics(context),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator(color: AppColors.primary)),
          SizedBox(height: 600),
        ],
      );

  Widget _buildError(ThemeData theme) => ListView(
        physics: _refreshPhysics(context),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 200),
                Icon(Icons.error_outline,
                    color: theme.colorScheme.error, size: 60),
                const SizedBox(height: 12),
                Text(
                  'حدث خطأ أثناء تحميل الكورسات',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                  onPressed: () => _fetchCourses(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ],
      );

  Widget _buildEmpty(ThemeData theme) => ListView(
        physics: _refreshPhysics(context),
        children: [
          const SizedBox(height: 200),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_rounded,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد كورسات مقترحة حالياً',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'سيتم عرض الكورسات المناسبة قريباً',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 600),
            ],
          ),
        ],
      );

  Widget _buildGrid(ThemeData theme, bool isDark) {
    return GridView.builder(
      controller: _scrollController,
      primary: false,
      physics: _refreshPhysics(context),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 230,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _courses.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _courses.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final c = _courses[index];
        return _buildCourseCard(theme, c, isDark);
      },
    );
  }

  Widget _buildCourseCard(
    ThemeData theme,
    Map<String, dynamic> c,
    bool isDark,
  ) {
    final price = NumberFormat(
      '#,###',
    ).format(double.tryParse(c['price'].toString()) ?? 0);
    final distance = (c['distance'] ?? 0).toStringAsFixed(1);
    final imgUrl = _resolveImage(c);
    final gradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF1E1E2E), const Color(0xFF2A2A3E)]
          : [Colors.white, const Color(0xFFF7F8FA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return InkWell(
      onTap: () =>
          Navigator.pushNamed(context, '/course-details', arguments: c['id']),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // صورة الكورس
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Image.network(
                imgUrl,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 110,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.school_rounded,
                    color: theme.colorScheme.primary,
                    size: 40,
                  ),
                ),
              ),
            ),

            // محتوى البطاقة
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c['course_name'] ?? 'دورة بدون اسم',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c['subject_name'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            "$distance كم",
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.attach_money,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            price,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            c['teacher_name'] ?? 'غير معروف',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveImage(Map<String, dynamic> c) {
    final imgs = c['course_images'] as List?;
    if (imgs != null && imgs.isNotEmpty) {
      final p = imgs.first.toString();
      if (p.startsWith('http')) return p;
      return '${AppConfig.serverBaseUrl}$p';
    }
    return '${AppConfig.serverBaseUrl}/uploads/default-course.jpg';
  }
}
