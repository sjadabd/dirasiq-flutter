import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mulhimiq/core/config/app_config.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:mulhimiq/shared/themes/app_colors.dart';
import 'package:mulhimiq/shared/widgets/global_app_bar.dart';
import 'package:mulhimiq/shared/widgets/status_views.dart';

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
      // No image available: return empty string to avoid 404 requests
      return '';
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
      SizedBox(height: 120),
      StatusView.loading(message: 'جارٍ تحميل دوراتك…'),
      SizedBox(height: 600),
    ],
  );

  Widget _buildError(ThemeData theme) => ListView(
    physics: _refreshPhysics(context),
    children: [
      const SizedBox(height: 120),
      StatusView.error(
        message: 'تعذّر تحميل دوراتك. تحقّق من الإنترنت وحاول مجدّداً.',
        onAction: () => _fetch(refresh: true),
      ),
      const SizedBox(height: 600),
    ],
  );

  Widget _buildEmpty(ThemeData theme) => ListView(
    physics: _refreshPhysics(context),
    children: const [
      SizedBox(height: 120),
      StatusView.empty(
        icon: Icons.school_rounded,
        message: 'لم تنضم لأي دورة بعد. تصفّح الكورسات المقترحة لتبدأ.',
      ),
      SizedBox(height: 600),
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
              // Phase 6: route to the unified Course Hub when the
              // feature flag is on; otherwise keep the legacy 8-action
              // grid the production app has shipped for months.
              final route = AppConfig.useNewCourseHub
                  ? '/course-hub'
                  : '/enrollment-actions';
              Get.toNamed(
                route,
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
                  child: imageUrl.isEmpty
                      ? Container(
                          width: 110,
                          height: 100,
                          color: cs.surfaceContainerHighest,
                          child: Icon(Icons.school, color: cs.onSurfaceVariant),
                        )
                      : Image.network(
                          imageUrl,
                          width: 110,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 110,
                            height: 100,
                            color: cs.surfaceContainerHighest,
                            child: Icon(
                              Icons.school,
                              color: cs.onSurfaceVariant,
                            ),
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
        bg = Colors.amber.withValues(alpha: 0.2);
        fg = Colors.amber.shade800;
        break;
      case 'rejected':
        bg = Colors.red.withValues(alpha: 0.2);
        fg = Colors.red.shade700;
        break;
      default:
        bg = cs.surfaceContainerHighest;
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
