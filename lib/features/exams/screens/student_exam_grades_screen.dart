import 'package:flutter/material.dart';
import 'package:mulhimiq/shared/widgets/global_app_bar.dart';
import 'package:mulhimiq/shared/themes/app_colors.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:intl/intl.dart';

class StudentExamGradesScreen extends StatefulWidget {
  const StudentExamGradesScreen({super.key});

  @override
  State<StudentExamGradesScreen> createState() =>
      _StudentExamGradesScreenState();
}

class _StudentExamGradesScreenState extends State<StudentExamGradesScreen> {
  final _api = ApiService();
  bool _loading = false;
  String? _error;
  final String _reportType = 'monthly';
  dynamic _report;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  List<Map<String, dynamic>> _safeListOfMaps(dynamic v) {
    if (v is List) {
      try {
        return v
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy', 'ar').format(d);
    } catch (_) {
      return iso;
    }
  }

  Map<String, dynamic> _safeMap(dynamic v) {
    if (v is Map) {
      try {
        return Map<String, dynamic>.from(v);
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  Future<void> _fetchReport() async {
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final List<Map<String, dynamic>> report = await _api
          .fetchStudentExamReportByType(type: _reportType);
      setState(() => _report = report);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const GlobalAppBar(title: 'الدرجات الشهرية', centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _fetchReport,
        child: ListView(
          padding: const EdgeInsets.all(12),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_error != null)
              _buildErrorCard(isDark)
            else if (_report != null)
              (_report is List
                  ? _reportListView(_safeListOfMaps(_report), isDark)
                  : _reportView(_safeMap(_report), isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'تقرير الامتحانات الشهرية',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: AppColors.error,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportListView(List<Map<String, dynamic>> items, bool isDark) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 40,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(height: 8),
              Text(
                'لا توجد درجات',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: items.map((it) => _examGradeCard(it, isDark)).toList(),
    );
  }

  Widget _examGradeCard(Map<String, dynamic> it, bool isDark) {
    final exam = Map<String, dynamic>.from(it['exam'] ?? {});
    final grade = (it['grade'] is Map)
        ? Map<String, dynamic>.from(it['grade'])
        : <String, dynamic>{};

    final examName = (exam['title']?.toString().trim().isNotEmpty ?? false)
        ? exam['title'].toString()
        : (exam['description']?.toString().trim().isNotEmpty ?? false)
        ? exam['description'].toString()
        : 'امتحان شهري';

    final maxScore = exam['max_score']?.toString() ?? '-';
    final score = grade['score']?.toString() ?? '-';
    final type = (exam['exam_type'] ?? 'monthly').toString();
    final dateRaw =
        (exam['exam_date'] ?? exam['date'] ?? exam['created_at'] ?? '')
            .toString();

    String dateText = '';
    if (dateRaw.isNotEmpty) {
      try {
        dateText = _formatDate(dateRaw);
      } catch (_) {
        dateText = dateRaw;
      }
    }

    // Calculate score color
    Color scoreColor = AppColors.info;
    double? percentage;
    if (score != '-' && maxScore != '-') {
      final s = double.tryParse(score) ?? 0;
      final m = double.tryParse(maxScore) ?? 0;
      if (m > 0) {
        percentage = (s / m) * 100;
        if (percentage >= 50) {
          scoreColor = AppColors.success;
        } else {
          scoreColor = AppColors.error;
        }
      }
    }

    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [surfaceColor, surfaceColor.withValues(alpha: 0.95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assessment_outlined,
                    size: 14,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    examName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scoreColor.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '$score/$maxScore',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _infoChip(Icons.calendar_today_outlined, dateText, isDark),
                const SizedBox(width: 6),
                _infoChip(
                  Icons.category_outlined,
                  type == 'monthly'
                      ? 'شهري'
                      : type == 'daily'
                      ? 'يومي'
                      : type,
                  isDark,
                ),
                if (percentage != null) ...[
                  const SizedBox(width: 6),
                  _infoChip(
                    Icons.percent,
                    '${percentage.toStringAsFixed(0)}%',
                    isDark,
                    color: scoreColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, bool isDark, {Color? color}) {
    final chipColor =
        color ??
        (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05));
    final textColor = color ?? (isDark ? Colors.white70 : Colors.black54);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 9,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportView(Map<String, dynamic> r, bool isDark) {
    final subject = (r['subject_name'] ?? '').toString();
    final course = (r['course_name'] ?? '').toString();
    final maxScore = (r['max_score'] ?? '').toString();
    final studentScore = (r['student_score'] ?? '-').toString();
    final description = (r['description'] ?? '').toString();
    final notes = (r['notes'] ?? '').toString();
    final examType = (r['exam_type'] ?? '').toString();
    final dateRaw = (r['exam_date'] ?? r['date'] ?? '').toString();

    String dateText = '';
    if (dateRaw.isNotEmpty) {
      dateText = _formatDate(dateRaw);
    }

    Color scoreColor = AppColors.info;
    double? percentage;
    if (studentScore != '-' && maxScore.isNotEmpty) {
      final s = double.tryParse(studentScore) ?? 0;
      final m = double.tryParse(maxScore) ?? 0;
      if (m > 0) {
        percentage = (s / m) * 100;
        scoreColor = percentage >= 50 ? AppColors.success : AppColors.error;
      }
    }

    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [surfaceColor, surfaceColor.withValues(alpha: 0.95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: scoreColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subject.isNotEmpty ? subject : 'تقرير الامتحان',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scoreColor.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '$studentScore/$maxScore',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
            if (percentage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.percent, size: 12, color: scoreColor),
                    const SizedBox(width: 4),
                    Text(
                      'النسبة: ${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (course.isNotEmpty)
              _infoRow(Icons.book_outlined, 'الكورس', course, isDark),
            if (examType.isNotEmpty)
              _infoRow(
                Icons.category_outlined,
                'النوع',
                examType == 'monthly' ? 'شهري' : examType,
                isDark,
              ),
            if (dateText.isNotEmpty)
              _infoRow(
                Icons.calendar_today_outlined,
                'التاريخ',
                dateText,
                isDark,
              ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              _sectionTitle('الوصف', isDark),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.4,
                ),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              _sectionTitle('الملاحظات', isDark),
              const SizedBox(height: 4),
              Text(
                notes,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 12, color: isDark ? Colors.white54 : Colors.black54),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, bool isDark) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}
