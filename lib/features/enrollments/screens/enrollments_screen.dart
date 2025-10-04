import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';

class EnrollmentsScreen extends StatefulWidget {
  const EnrollmentsScreen({super.key});

  @override
  State<EnrollmentsScreen> createState() => _EnrollmentsScreenState();
}

class _EnrollmentsScreenState extends State<EnrollmentsScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetch(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) _fetch();
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
      final pagination = Map<String, dynamic>.from(res['pagination'] ?? {});
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
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  String _fullImageUrl(String? path) {
    if (path == null || path.isEmpty) {
      return '${AppConfig.serverBaseUrl}/uploads/defaults/default-course.jpg';
    }
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return '${AppConfig.serverBaseUrl}$path';
    return '${AppConfig.serverBaseUrl}/$path';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const GlobalAppBar(title: "دوراتي المسجّلة", centerTitle: true),
      body: RefreshIndicator(
        displacement: 36,
        color: AppColors.primary,
        onRefresh: () => _fetch(refresh: true),
        child: _loading
            ? _buildLoading()
            : _error != null
            ? _buildError(theme)
            : _items.isEmpty
            ? _buildEmpty(theme)
            : _buildList(theme, isDark),
      ),
    );
  }

  ScrollPhysics _refreshPhysics(BuildContext ctx) {
    final platform = Theme.of(ctx).platform;
    final parent =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
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
          children: [
            const SizedBox(height: 200),
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 60),
            const SizedBox(height: 12),
            Text(
              'حدث خطأ أثناء تحميل الدورات المسجّلة',
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
              onPressed: () => _fetch(refresh: true),
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
            'لا توجد دورات مسجّل بها',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'قم بالانضمام إلى دورة جديدة من صفحة الكورسات المقترحة',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 600),
        ],
      ),
    ],
  );

  Widget _buildList(ThemeData theme, bool isDark) {
    final cs = theme.colorScheme;
    return ListView.builder(
      controller: _scrollController,
      physics: _refreshPhysics(context),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final item = _items[index];
        final course = Map<String, dynamic>.from(item['course'] ?? {});
        final teacher = Map<String, dynamic>.from(item['teacher'] ?? {});
        final status = (item['status'] ?? '').toString();
        final startDate = _formatDate(item['course']?['startDate']);

        final imageUrl = _fullImageUrl(
          (course['course_images'] != null &&
                  course['course_images'] is List &&
                  (course['course_images'] as List).isNotEmpty)
              ? (course['course_images'] as List).first.toString()
              : '',
        );

        return InkWell(
          onTap: () {
            final courseId = course['id']?.toString();
            final courseName = course['name']?.toString();
            if (courseId != null && courseId.isNotEmpty) {
              Get.toNamed(
                '/enrollment-actions',
                arguments: {
                  'courseId': courseId,
                  'courseName': courseName,
                  'teacherId': (item['teacher']?['id'])?.toString(),
                },
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                  child: Image.network(
                    imageUrl,
                    width: 110,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 110,
                      height: 100,
                      color: cs.surfaceVariant,
                      child: Icon(Icons.school, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course['name']?.toString() ?? 'دورة بدون اسم',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الأستاذ: ${teacher['name'] ?? 'غير معروف'}',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _statusChip(status, cs),
                            const Spacer(),
                            if (startDate.isNotEmpty)
                              Text(
                                startDate,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
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
      },
    );
  }

  Widget _statusChip(String status, ColorScheme cs) {
    Color bg, fg;
    String label = _translateStatus(status);
    switch (status) {
      case 'confirmed':
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        break;
      case 'pending':
        bg = Colors.amber.withOpacity(0.2);
        fg = Colors.amber.shade800;
        break;
      case 'rejected':
        bg = Colors.red.withOpacity(0.2);
        fg = Colors.red.shade700;
        break;
      default:
        bg = cs.surfaceVariant;
        fg = cs.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'confirmed':
        return 'مؤكَّد';
      case 'pending':
        return 'قيد الانتظار';
      case 'rejected':
        return 'مرفوض';
      case 'canceled':
        return 'ملغى';
      default:
        return 'غير معروف';
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('yyyy/MM/dd').format(d);
    } catch (_) {
      return '';
    }
  }
}
