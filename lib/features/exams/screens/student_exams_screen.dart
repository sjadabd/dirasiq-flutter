import 'package:flutter/material.dart';
import 'package:mulhimiq/shared/widgets/global_app_bar.dart';
import 'package:mulhimiq/shared/themes/app_colors.dart';
import 'package:mulhimiq/core/services/api_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
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
          padding: const EdgeInsets.all(12),
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppColors.error, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            if (_loading && _items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ..._items.map(_examTile),
            if (_loading && _items.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            if (!_loading && _items.isEmpty && _error == null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'لا توجد امتحانات',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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

  Widget _examTile(Map<String, dynamic> e) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        dateText = dateRaw;
      }
    }

    // تحديد اللون حسب نوع الامتحان
    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    if (type == 'monthly') {
      typeColor = AppColors.warning;
      typeIcon = Icons.calendar_month;
      typeLabel = 'شهري';
    } else if (type == 'daily') {
      typeColor = AppColors.primary;
      typeIcon = Icons.calendar_today;
      typeLabel = 'يومي';
    } else {
      typeColor = AppColors.info;
      typeIcon = Icons.assignment;
      typeLabel = type;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.darkSurface, AppColors.darkSurface]
              : [Colors.white, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : typeColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openExamDetails(e['id']?.toString()),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // العنوان مع نوع الامتحان
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_left,
                      color: isDark ? Colors.white54 : Colors.black45,
                      size: 18,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // المعلومات الأساسية
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    if (subject.isNotEmpty)
                      _infoChip(
                        Icons.book,
                        subject,
                        AppColors.tertiary,
                        isDark,
                      ),
                    if (course.isNotEmpty)
                      _infoChip(
                        Icons.class_,
                        course,
                        AppColors.success,
                        isDark,
                      ),
                    if (maxScore.isNotEmpty)
                      _infoChip(
                        Icons.grade,
                        maxScore,
                        AppColors.tertiary,
                        isDark,
                      ),
                    if (dateText.isNotEmpty)
                      _infoChip(Icons.event, dateText, AppColors.info, isDark),
                  ],
                ),

                // الوصف
                if ((e['description']?.toString().trim().isNotEmpty ??
                    false)) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.description,
                          size: 12,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            e['description'].toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // الملاحظات
                if ((e['notes']?.toString().trim().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.tertiary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.note_alt,
                          size: 12,
                          color: AppColors.tertiary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            e['notes'].toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? color.withValues(alpha: 0.9) : color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExamDetails(String? id) async {
    if (id == null || id.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
    );

    try {
      final details = await _api.fetchStudentExamById(id);
      Map<String, dynamic>? my;
      try {
        my = await _api.fetchStudentExamMyGrade(id);
      } catch (_) {
        my = null;
      }

      if (!mounted) return;
      Navigator.pop(context); // إغلاق loading

      final isDark = Theme.of(context).brightness == Brightness.dark;
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
      if (dateStr != null && dateStr.trim().isNotEmpty) {
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
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.darkSurface, AppColors.darkBackground]
                    : [Colors.white, AppColors.primary.withValues(alpha: 0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.assignment,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          titleText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // المعلومات الأساسية
                        if (subjectName.isNotEmpty)
                          _detailRow(
                            Icons.book,
                            'المادة',
                            subjectName,
                            AppColors.primary,
                            isDark,
                          ),
                        if (courseName.isNotEmpty)
                          _detailRow(
                            Icons.class_,
                            'الكورس',
                            courseName,
                            AppColors.success,
                            isDark,
                          ),
                        if (maxScore != null)
                          _detailRow(
                            Icons.grade,
                            'الدرجة القصوى',
                            maxScore,
                            AppColors.warning,
                            isDark,
                          ),
                        if (studentScore != null)
                          _detailRow(
                            Icons.stars,
                            'درجتي',
                            studentScore,
                            AppColors.success,
                            isDark,
                          ),
                        if (examDate != null)
                          _detailRow(
                            Icons.event,
                            'التاريخ',
                            _formatDate(examDate),
                            AppColors.info,
                            isDark,
                          ),
                        if (examDate != null)
                          _detailRow(
                            Icons.access_time,
                            'الحالة',
                            _relativeFromNow(examDate),
                            AppColors.secondary,
                            isDark,
                          ),

                        const SizedBox(height: 10),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey[300],
                        ),
                        const SizedBox(height: 10),

                        // الوصف
                        if ((details['description']
                                ?.toString()
                                .trim()
                                .isNotEmpty ??
                            false)) ...[
                          _sectionHeader(
                            Icons.description,
                            'الوصف',
                            AppColors.info,
                            isDark,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              details['description'].toString(),
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // الملاحظات
                        if ((details['notes']?.toString().trim().isNotEmpty ??
                            false)) ...[
                          _sectionHeader(
                            Icons.note_alt,
                            'الملاحظات',
                            AppColors.warning,
                            isDark,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              details['notes'].toString(),
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // درجتي التفصيلية
                        if (my != null) ...[
                          Divider(
                            height: 1,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey[300],
                          ),
                          const SizedBox(height: 10),
                          _sectionHeader(
                            Icons.assessment,
                            'تفاصيل درجتي',
                            AppColors.primary,
                            isDark,
                          ),
                          const SizedBox(height: 6),
                          if (my['status'] != null)
                            _detailRow(
                              Icons.check_circle,
                              'الحالة',
                              my['status'],
                              AppColors.success,
                              isDark,
                            ),
                          if (my['feedback'] != null)
                            _detailRow(
                              Icons.comment,
                              'ملاحظات المعلم',
                              my['feedback'],
                              AppColors.info,
                              isDark,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.grey[50],
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'إغلاق',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // إغلاق loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _sectionHeader(IconData icon, String title, Color color, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    dynamic value,
    Color color,
    bool isDark,
  ) {
    final text = (value ?? '').toString();
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
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
    if (abs.inDays >= 1) {
      human = '${abs.inDays} يوم';
    } else if (abs.inHours >= 1) {
      human = '${abs.inHours} ساعة';
    } else if (abs.inMinutes >= 1) {
      human = '${abs.inMinutes} دقيقة';
    } else {
      human = '${abs.inSeconds} ثانية';
    }
    return isFuture ? 'يبقى $human' : 'انتهى منذ $human';
  }
}
