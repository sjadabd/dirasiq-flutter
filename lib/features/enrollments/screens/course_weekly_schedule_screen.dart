import 'package:flutter/material.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:intl/intl.dart';

class CourseWeeklyScheduleScreen extends StatefulWidget {
  final String courseId;
  final String? courseName;

  const CourseWeeklyScheduleScreen({
    super.key,
    required this.courseId,
    this.courseName,
  });

  @override
  State<CourseWeeklyScheduleScreen> createState() =>
      _CourseWeeklyScheduleScreenState();
}

class _CourseWeeklyScheduleScreenState
    extends State<CourseWeeklyScheduleScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.fetchWeeklyScheduleByCourse(widget.courseId);
      list.sort((a, b) {
        final wa = (a['weekday'] ?? 0) as int;
        final wb = (b['weekday'] ?? 0) as int;
        final sa = (a['startTime'] ?? '') as String;
        final sb = (b['startTime'] ?? '') as String;
        final c = wa.compareTo(wb);
        if (c != 0) return c;
        return sa.compareTo(sb);
      });
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.courseName != null && widget.courseName!.isNotEmpty
        ? 'جدول الأسبوع • ${widget.courseName}'
        : 'جدول الأسبوع';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlobalAppBar(title: title, centerTitle: true),
      body: RefreshIndicator(onRefresh: _fetch, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
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
              onPressed: _fetch,
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
          Center(child: Text('لا توجد جلسات مجدولة')),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = _items[index];
        final title = (s['title'] ?? s['courseName'] ?? '').toString();
        final weekday = _weekdayName((s['weekday'] ?? 0) as int);
        final start = _fmtTime(s['startTime']);
        final end = _fmtTime(s['endTime']);
        final teacher = (s['teacherName'] ?? '').toString();

        return Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.withOpacity(.12),
              child: const Icon(Icons.event, color: Colors.teal),
            ),
            title: Text(title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text('اليوم: $weekday'),
                const SizedBox(height: 2),
                Text('الوقت: $start - $end'),
                if (teacher.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('المعلم: $teacher'),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _weekdayName(int w) {
    // 1=Mon ... 7=Sun حسب بياناتك
    const names = {
      0: 'الأحد',
      1: 'الإثنين',
      2: 'الثلاثاء',
      3: 'الأربعاء',
      4: 'الخميس',
      5: 'الجمعة',
      6: 'السبت',
    };
    return names[w] ?? w.toString();
  }

  String _fmtTime(dynamic t) {
    final s = t?.toString() ?? '';
    if (s.isEmpty) return '';
    try {
      // صيغة "HH:mm:ss"
      final dt = DateFormat('HH:mm:ss').parse(s);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return s;
    }
  }
}
