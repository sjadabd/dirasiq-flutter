import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';

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
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: GlobalAppBar(title: title, centerTitle: true),
      body: RefreshIndicator(onRefresh: _fetch, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.error_outline, size: 50, color: colorScheme.error),
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

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final s = _items[index];
        final title = (s['title'] ?? s['courseName'] ?? '').toString();
        final weekday = _weekdayName((s['weekday'] ?? 0) as int);
        final start = _fmtTime(s['startTime']);
        final end = _fmtTime(s['endTime']);
        final teacher = (s['teacherName'] ?? '').toString();
        final imageUrl =
            s['imageUrl'] ??
            "http://192.168.68.104:3000/uploads/defaults/default-course.jpg";

        // 🎨 تحديد لون البوردر حسب المود
        final borderColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.white12
            : Colors.grey.shade300;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1), // ✅ البوردر
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                width: 55,
                height: 55,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 55,
                  height: 55,
                  color: colorScheme.primary.withOpacity(0.1),
                  child: const Icon(Icons.book, color: Colors.teal),
                ),
              ),
            ),
            title: Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(Icons.calendar_today, 'اليوم: $weekday'),
                  _infoRow(Icons.access_time, 'الوقت: $start - $end'),
                  if (teacher.isNotEmpty)
                    _infoRow(Icons.person, 'المعلم: $teacher'),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 24),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayName(int w) {
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
      final dt = DateFormat('HH:mm:ss').parse(s);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return s;
    }
  }
}
