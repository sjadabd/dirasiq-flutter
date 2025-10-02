import 'package:flutter/material.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/core/services/api_service.dart';

class StudentExamsScreen extends StatefulWidget {
  final String fixedType; // 'daily' or 'monthly'
  final String? title;
  const StudentExamsScreen({super.key, required this.fixedType, this.title});

  @override
  State<StudentExamsScreen> createState() => _StudentExamsScreenState();
}

class _StudentExamsScreenState extends State<StudentExamsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  int _page = 1;
  final int _limit = 10;
  late String _type;
  List<Map<String, dynamic>> _items = [];
  bool _hasMore = true;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _type = widget.fixedType;
    _fetch(reset: true);
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 200) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _items = [];
        _hasMore = true;
      });
    }
    try {
      final res = await _api.fetchStudentExams(
        page: _page,
        limit: _limit,
        type: _type,
      );
      // Expect format: { success, data: [...], pagination: { page, limit, total } } or similar
      final data = res['data'];
      final list = (data is List)
          ? List<Map<String, dynamic>>.from(data)
          : <Map<String, dynamic>>[];
      setState(() {
        _items.addAll(list);
        _hasMore = list.length == _limit;
        _page += 1;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await _fetch(reset: true);
  }

  // type selector removed; this screen is fixed to one type

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GlobalAppBar(
        title:
            widget.title ??
            'الامتحانات: ${_type == 'monthly' ? 'شهري' : 'يومي'}',
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _controller,
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 4),
            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ),
            if (_loading && _items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: CircularProgressIndicator(),
                ),
              ),
            ..._items.map(_examTile).toList(),
            if (_loading && _items.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_loading && _items.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: Text('لا توجد امتحانات')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _examTile(Map<String, dynamic> e) {
    final title = (e['title'] ?? e['name'] ?? 'امتحان').toString();
    final type = (e['type'] ?? _type).toString();
    final subject = (e['subject_name'] ?? '').toString();
    final course = (e['course_name'] ?? '').toString();
    final maxScore = (e['max_score'] ?? e['maxScore'] ?? '').toString();
    final dateRaw = (e['date'] ?? e['exam_date'] ?? e['created_at'] ?? '')
        .toString();
    String dateText = '';
    if (dateRaw.isNotEmpty) {
      try {
        final dt = DateTime.parse(dateRaw);
        dateText = _formatDate(dt);
      } catch (_) {
        dateText = dateRaw; // fallback to raw if parsing fails
      }
    }

    return Card(
      elevation: 1,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subject.isNotEmpty) Text('📘 المادة: $subject'),
            if (course.isNotEmpty) Text('📚 الكورس: $course'),
            Text(
              '📝 النوع: ${type == "monthly"
                  ? "امتحان شهري"
                  : type == "daily"
                  ? "امتحان يومي"
                  : type}',
            ),
            if (maxScore.isNotEmpty) Text('🎯 الدرجة القصوى: $maxScore'),
            if (dateText.isNotEmpty) Text('📅 التاريخ: $dateText'),

            // ✅ الوصف
            if ((e['description']?.toString().trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              Text(
                "الوصف:",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                e['description'].toString(),
                style: const TextStyle(color: Colors.black87),
              ),
            ],

            // ✅ الملاحظات
            if ((e['notes']?.toString().trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              Text(
                "الملاحظات:",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                e['notes'].toString(),
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ],
        ),

        trailing: const Icon(Icons.chevron_left),
        onTap: () => _openExamDetails(e['id']?.toString()),
      ),
    );
  }

  Future<void> _openExamDetails(String? id) async {
    if (id == null || id.isEmpty) return;
    try {
      final details = await _api.fetchStudentExamById(id);
      // New API shape includes student_score in details; my-grade may be redundant
      Map<String, dynamic>? my;
      try {
        my = await _api.fetchStudentExamMyGrade(id);
      } catch (_) {
        my = null;
      }
      if (!mounted) return;
      // normalize fields from new shape
      final subjectName = (details['subject_name'] ?? '').toString();
      final courseName = (details['course_name'] ?? '').toString();
      final examType = (details['exam_type'] ?? details['type'] ?? _type)
          .toString();
      final maxScore = (details['max_score'] ?? details['maxScore'])
          ?.toString();
      final studentScore = (details['student_score'] ?? my?['score'])
          ?.toString();
      final dateStr =
          (details['exam_date'] ??
                  details['date'] ??
                  details['examDate'] ??
                  details['created_at'])
              ?.toString();
      DateTime? examDate;
      if (dateStr != null && dateStr.toString().trim().isNotEmpty) {
        try {
          examDate = DateTime.parse(dateStr);
        } catch (_) {}
      }
      final titleText = (details['title']?.toString().trim().isNotEmpty == true)
          ? details['title'].toString()
          : (subjectName.isNotEmpty
                ? 'امتحان ${examType == 'monthly'
                      ? 'شهري'
                      : examType == 'daily'
                      ? 'يومي'
                      : examType} - $subjectName'
                : 'تفاصيل الامتحان');
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(titleText),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _row('المادة', subjectName),
                _row('الكورس', courseName),
                _row('الدرجة القصوى', maxScore),
                if (studentScore != null) _row('درجتي', studentScore),
                if (examDate != null) _row('التاريخ', _formatDate(examDate)),
                if (examDate != null)
                  _row('الحالة الزمنية', _relativeFromNow(examDate)),

                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // ✅ الوصف
                if ((details['description']?.toString().trim().isNotEmpty ??
                    false)) ...[
                  Row(
                    children: const [
                      Icon(Icons.description, size: 20, color: Colors.blue),
                      SizedBox(width: 6),
                      Text(
                        'الوصف',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details['description'].toString(),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                ],

                // ✅ الملاحظات
                if ((details['notes']?.toString().trim().isNotEmpty ??
                    false)) ...[
                  Row(
                    children: const [
                      Icon(Icons.note_alt, size: 20, color: Colors.orange),
                      SizedBox(width: 6),
                      Text(
                        'الملاحظات',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details['notes'].toString(),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                ],

                const Divider(),
                if (my != null) ...[
                  const Text(
                    'تفاصيل إضافية لدرجتي',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  _row('الحالة', my['status']),
                  if (my['feedback'] != null) _row('ملاحظات', my['feedback']),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  String _formatDate(DateTime dt) {
    // Simple yyyy-MM-dd; adjust if you want localized formatting
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _relativeFromNow(DateTime when) {
    final now = DateTime.now();
    final diff = when.difference(now);
    final isFuture = diff.inMilliseconds > 0;
    final abs = diff.abs();
    String human;
    if (abs.inDays >= 1)
      human = '${abs.inDays} يوم';
    else if (abs.inHours >= 1)
      human = '${abs.inHours} ساعة';
    else if (abs.inMinutes >= 1)
      human = '${abs.inMinutes} دقيقة';
    else
      human = '${abs.inSeconds} ثانية';
    return isFuture ? 'يبقى $human' : 'انتهى منذ $human';
  }

  Widget _row(String label, dynamic value) {
    final text = (value ?? '').toString();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
