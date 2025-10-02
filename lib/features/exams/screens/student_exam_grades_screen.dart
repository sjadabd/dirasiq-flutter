import 'package:flutter/material.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/core/services/api_service.dart';
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
  String _reportType = 'monthly'; // ثابت: شهري
  dynamic _report; // can be Map or List depending on API shape
  // لم نعد نستخدم إدخال معرف الامتحان أو تحميل درجة منفصلة

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  // Helpers
  List<Map<String, dynamic>> _safeListOfMaps(dynamic v) {
    if (v is List) {
      try {
        return v
            .where((e) => e is Map)
            .map((e) => Map<String, dynamic>.from(e as Map))
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
      return DateFormat('dd/MM/yyyy - hh:mm a', 'ar').format(d);
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

  Widget _reportListView(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا توجد بيانات للعرض'));
    }
    return Column(
      children: items.map((it) {
        final exam = Map<String, dynamic>.from(it['exam'] ?? {});
        final grade = (it['grade'] is Map)
            ? Map<String, dynamic>.from(it['grade'])
            : <String, dynamic>{};
        final examName = (exam['title']?.toString().trim().isNotEmpty ?? false)
            ? exam['title'].toString()
            : (exam['description']?.toString().trim().isNotEmpty ?? false)
            ? exam['description'].toString()
            : 'امتحان شهري';
        final maxScore = exam['max_score']?.toString();
        final score = grade['score']?.toString();
        final type = (exam['exam_type'] ?? '').toString();
        final dateRaw =
            (exam['exam_date'] ?? exam['date'] ?? exam['created_at'] ?? '')
                .toString();
        String dateText = '';
        if (dateRaw.isNotEmpty) {
          try {
            final dt = DateTime.parse(dateRaw).toLocal();
            dateText =
                '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          } catch (_) {
            dateText = dateRaw;
          }
        }
        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  examName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                if (dateText.isNotEmpty) Text('التاريخ: $dateText'),
                Text(
                  'نوع الامتحان: ${type == 'monthly'
                      ? 'شهري'
                      : type == 'daily'
                      ? 'يومي'
                      : type}',
                ),
                if (maxScore != null) Text('الدرجة القصوى: $maxScore'),
                if (score != null) Text('درجتك: $score'),
              ],
            ),
          ),
        );
      }).toList(),
    );
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

  // أزيلت دالة جلب الدرجة حسب معرف امتحان

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GlobalAppBar(
        title: 'الدرجات - الامتحانات الشهرية',
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '📊 تقرير الامتحانات الشهرية ودرجتك',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Card(
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_report != null)
            (_report is List
                ? _reportListView(_safeListOfMaps(_report))
                : _reportView(_safeMap(_report))),
        ],
      ),
    );
  }

  Widget _reportView(Map<String, dynamic> r) {
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
      try {
        dateText = _formatDate(dateRaw);
      } catch (_) {
        dateText = dateRaw;
      }
    }

    // ✅ لون حسب نجاح/رسوب الطالب
    Color scoreColor = Colors.blueAccent;
    if (studentScore != '-' && maxScore.isNotEmpty) {
      final s = int.tryParse(studentScore) ?? 0;
      final m = int.tryParse(maxScore) ?? 0;
      if (m > 0) {
        final ratio = s / m;
        if (ratio >= 0.5) {
          scoreColor = Colors.green; // ناجح
        } else {
          scoreColor = Colors.red; // راسب
        }
      }
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان + الدرجة
            Row(
              children: [
                const Icon(Icons.bar_chart, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subject.isNotEmpty
                        ? "تقرير الامتحان - $subject"
                        : "تقرير الامتحان",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$studentScore / $maxScore",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            if (course.isNotEmpty) _infoRow(Icons.book, "الكورس", course),
            if (examType.isNotEmpty)
              _infoRow(
                Icons.category,
                "نوع الامتحان",
                examType == "monthly" ? "شهري" : examType,
              ),
            if (dateText.isNotEmpty)
              _infoRow(Icons.date_range, "التاريخ", dateText),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionTitle("الوصف"),
              Text(description, style: const TextStyle(fontSize: 14)),
            ],

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionTitle("الملاحظات"),
              Text(
                notes,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  // أزيل عرض الدرجة الفردية لأن الشاشة تعرض تقريرًا شهريًا فقط
}
