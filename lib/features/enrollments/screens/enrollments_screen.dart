import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:dirasiq/core/services/api_service.dart';

class EnrollmentsScreen extends StatefulWidget {
  const EnrollmentsScreen({super.key});

  @override
  State<EnrollmentsScreen> createState() => _EnrollmentsScreenState();
}

class _EnrollmentsScreenState extends State<EnrollmentsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _hasMore = true;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetch(refresh: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      if (!_loading && _hasMore) _fetch();
    }
  }

  Future<void> _fetch({bool refresh = false}) async {
    try {
      if (refresh) {
        setState(() {
          _loading = true;
          _error = null;
          _page = 1;
          _items = [];
          _hasMore = true;
        });
      }
      final res = await _api.fetchStudentEnrollments(page: _page, limit: 10);
      final list = List<Map<String, dynamic>>.from(res['data'] ?? []);
      final pagination = Map<String, dynamic>.from(res['pagination'] ?? {});
      setState(() {
        _items.addAll(list);
        _loading = false;
        final total = pagination['total'] is int
            ? pagination['total'] as int
            : _items.length;
        _hasMore = _items.length < total;
        if (_hasMore) _page += 1;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GlobalAppBar(title: 'دوراتي المسجّلة', centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () => _fetch(refresh: true),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.error_outline, size: 40, color: Colors.red),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: () => _fetch(refresh: true),
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Center(child: Text('لا توجد دورات مسجّل بها')),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = _items[index];
        final course = Map<String, dynamic>.from(item['course'] ?? {});
        final teacher = Map<String, dynamic>.from(item['teacher'] ?? {});
        final status = (item['status'] ?? '').toString();
        final startDate = _formatDate(item['course']['startDate']);

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(.1),
              child: const Icon(Icons.school, color: Colors.blue),
            ),
            title: Text(course['name']?.toString() ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text('الأستاذ: ${teacher['name'] ?? ''}'),
                const SizedBox(height: 2),
                Text('الحالة: ${_translateStatus(status)}'),
                if (startDate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('تاريخ المباشرة: $startDate'),
                ],
              ],
            ),
            trailing: const Icon(Icons.chevron_left),
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
          ),
        );
      },
    );
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'confirmed':
        return 'مؤكّد';
      case 'pending':
        return 'قيد الانتظار';
      case 'rejected':
        return 'مرفوض';
      case 'canceled':
        return 'ملغى';
      default:
        return status;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('yyyy/MM/dd HH:mm').format(d);
    } catch (_) {
      return '';
    }
  }
}
