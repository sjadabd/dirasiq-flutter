import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:dirasiq/core/services/api_service.dart';

class StudentEvaluationsScreen extends StatefulWidget {
  final String? initialEvaluationId;
  const StudentEvaluationsScreen({super.key, this.initialEvaluationId});

  @override
  State<StudentEvaluationsScreen> createState() =>
      _StudentEvaluationsScreenState();
}

class _StudentEvaluationsScreenState extends State<StudentEvaluationsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _limit = 10;
  bool _hasMore = true;

  DateTime? _from;
  DateTime? _to;

  static const Map<String, String> _ratingAr = {
    'excellent': 'ممتاز',
    'very_good': 'جيد جدًا',
    'good': 'جيد',
    'fair': 'مقبول',
    'weak': 'ضعيف',
  };

  static const Map<String, Color> _ratingColors = {
    'excellent': AppColors.success,
    'very_good': Color(0xFF4CAF50),
    'good': AppColors.info,
    'fair': AppColors.warning,
    'weak': AppColors.error,
  };

  String _toAr(String? v) {
    if (v == null || v.isEmpty) return '—';
    return _ratingAr[v] ?? v;
  }

  Color _getColor(String? v) {
    if (v == null || v.isEmpty) return Colors.grey;
    return _ratingColors[v] ?? AppColors.primary;
  }

  Future<void> _openDetailsById(String id) async {
    try {
      final data = await _api.fetchStudentEvaluationById(id);
      if (!mounted) return;
      _openDetails(data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: const TextStyle(fontSize: 11),
          ),
        ),
      );
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('yyyy-MM-dd').format(d);
    } catch (_) {
      return iso;
    }
  }

  String _fmtYMD(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  void initState() {
    super.initState();
    _fetch(refresh: true).then((_) {
      if (widget.initialEvaluationId != null &&
          widget.initialEvaluationId!.isNotEmpty) {
        final found = _items.firstWhere(
          (e) =>
              (e['id'] ?? e['_id'] ?? '').toString() ==
              widget.initialEvaluationId,
          orElse: () => {},
        );
        if (found.isNotEmpty) {
          _openDetails(found);
        } else {
          _openDetailsById(widget.initialEvaluationId!);
        }
      }
    });
  }

  Future<void> _fetch({bool refresh = false}) async {
    try {
      if (refresh) {
        setState(() {
          _loading = true;
          _error = null;
          _items = [];
          _page = 1;
          _hasMore = true;
        });
      }

      if (!_hasMore && !refresh) return;

      final res = await _api.fetchStudentEvaluations(
        from: _from != null ? _fmtYMD(_from!) : null,
        to: _to != null ? _fmtYMD(_to!) : null,
        page: _page,
        limit: _limit,
      );

      final dataList = List<Map<String, dynamic>>.from(
        res['data'] ?? res['items'] ?? [],
      );
      final pagination = (res['pagination'] is Map)
          ? Map<String, dynamic>.from(res['pagination'])
          : <String, dynamic>{};
      final total = pagination['total'] is int
          ? pagination['total'] as int
          : null;

      setState(() {
        _items.addAll(dataList);
        _loading = false;
        if (total != null) {
          _hasMore = _items.length < total;
        } else {
          _hasMore = dataList.length == _limit;
        }
        if (_hasMore) _page += 1;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDate: _from ?? now,
      locale: const Locale('ar'),
    );
    if (d != null) {
      setState(() => _from = d);
      _fetch(refresh: true);
    }
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDate: _to ?? now,
      locale: const Locale('ar'),
    );
    if (d != null) {
      setState(() => _to = d);
      _fetch(refresh: true);
    }
  }

  void _clearFilters() {
    setState(() {
      _from = null;
      _to = null;
    });
    _fetch(refresh: true);
  }

  void _openDetails(Map<String, dynamic> ev) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [surfaceColor, surfaceColor.withOpacity(0.98)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          left: 14,
          right: 14,
          top: 14,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تفاصيل التقييم',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _kv(
                Icons.calendar_today_outlined,
                'التاريخ',
                _fmtDate(ev['eval_date']?.toString() ?? ev['date']?.toString()),
                isDark,
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey[300]!,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    _kvRating(
                      Icons.school_outlined,
                      'المستوى العلمي',
                      ev['scientific_level']?.toString(),
                      isDark,
                    ),
                    const SizedBox(height: 6),
                    _kvRating(
                      Icons.psychology_outlined,
                      'المستوى السلوكي',
                      ev['behavioral_level']?.toString(),
                      isDark,
                    ),
                    const SizedBox(height: 6),
                    _kvRating(
                      Icons.access_time_outlined,
                      'الانضباط الحضوري',
                      ev['attendance_level']?.toString(),
                      isDark,
                    ),
                    const SizedBox(height: 6),
                    _kvRating(
                      Icons.book_outlined,
                      'التحضير للواجبات',
                      ev['homework_preparation']?.toString(),
                      isDark,
                    ),
                    const SizedBox(height: 6),
                    _kvRating(
                      Icons.group_outlined,
                      'المشاركة',
                      ev['participation_level']?.toString(),
                      isDark,
                    ),
                    const SizedBox(height: 6),
                    _kvRating(
                      Icons.rule_outlined,
                      'اتباع التعليمات',
                      ev['instruction_following']?.toString(),
                      isDark,
                    ),
                  ],
                ),
              ),

              if ((ev['guidance']?.toString().trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                _sectionTitle('التوجيه', Icons.lightbulb_outline, isDark),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.info.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    ev['guidance'].toString(),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],

              if ((ev['notes']?.toString().trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                _sectionTitle('الملاحظات', Icons.note_outlined, isDark),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    ev['notes'].toString(),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _kv(IconData icon, String k, String? v, bool isDark) {
    final val = (v == null || v.trim().isEmpty) ? '—' : v;
    return Row(
      children: [
        Icon(icon, size: 12, color: isDark ? Colors.white54 : Colors.black54),
        const SizedBox(width: 6),
        Text(
          '$k: ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        Expanded(
          child: Text(
            val,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _kvRating(IconData icon, String label, String? value, bool isDark) {
    final val = _toAr(value);
    final color = _getColor(value);

    return Row(
      children: [
        Icon(icon, size: 12, color: color),
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3), width: 0.5),
            ),
            child: Text(
              val,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const GlobalAppBar(title: 'تقييماتي', centerTitle: true),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFrom,
                    icon: const Icon(Icons.date_range_outlined, size: 14),
                    label: Text(
                      _from != null ? _fmtYMD(_from!) : 'من تاريخ',
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTo,
                    icon: const Icon(Icons.date_range_outlined, size: 14),
                    label: Text(
                      _to != null ? _fmtYMD(_to!) : 'إلى تاريخ',
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'مسح',
                  onPressed: (_from != null || _to != null)
                      ? _clearFilters
                      : null,
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(isDark)),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: () => _fetch(refresh: true),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.inbox_outlined,
            size: 40,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          const SizedBox(height: 8),
          Text(
            'لا توجد تقييمات',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          _fetch();
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final ev = _items[index];
        final date = _fmtDate(
          ev['eval_date']?.toString() ?? ev['date']?.toString(),
        );

        final sci = ev['scientific_level']?.toString() ?? '';
        final sciColor = _getColor(sci);
        final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [surfaceColor, surfaceColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sciColor.withOpacity(0.2), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: sciColor.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openDetails(ev),
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
                            color: sciColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.fact_check_outlined,
                            size: 14,
                            color: sciColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date.isNotEmpty ? date : '—',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _chip(
                          Icons.school_outlined,
                          'علمي',
                          ev['scientific_level']?.toString(),
                          isDark,
                        ),
                        _chip(
                          Icons.psychology_outlined,
                          'سلوكي',
                          ev['behavioral_level']?.toString(),
                          isDark,
                        ),
                        _chip(
                          Icons.access_time_outlined,
                          'حضوري',
                          ev['attendance_level']?.toString(),
                          isDark,
                        ),
                        _chip(
                          Icons.book_outlined,
                          'واجب',
                          ev['homework_preparation']?.toString(),
                          isDark,
                        ),
                        _chip(
                          Icons.group_outlined,
                          'مشاركة',
                          ev['participation_level']?.toString(),
                          isDark,
                        ),
                        _chip(
                          Icons.rule_outlined,
                          'تعليمات',
                          ev['instruction_following']?.toString(),
                          isDark,
                        ),
                      ],
                    ),
                    if ((ev['notes']?.toString().trim().isNotEmpty ??
                        false)) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 12,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                ev['notes'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
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
      },
    );
  }

  Widget _chip(IconData icon, String label, String? value, bool isDark) {
    final val = _toAr(value);
    final color = _getColor(value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $val',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
