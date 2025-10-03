import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
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

  String _toAr(String? v) {
    if (v == null || v.isEmpty) return '—';
    return _ratingAr[v] ?? v;
  }

  Future<void> _openDetailsById(String id) async {
    try {
      final data = await _api.fetchStudentEvaluationById(id);
      if (!mounted) return;
      _openDetails(data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
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
        // حاول إيجاد التقييم ضمن الصفحة الحالية، وإن لم يوجد اجلبه مباشرة
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.fact_check, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'تفاصيل التقييم',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _kv(
                'التاريخ',
                _fmtDate(ev['eval_date']?.toString() ?? ev['date']?.toString()),
              ),
              _kv('المستوى العلمي', _toAr(ev['scientific_level']?.toString())),
              _kv('المستوى السلوكي', _toAr(ev['behavioral_level']?.toString())),
              _kv(
                'الانضباط الحضوري',
                _toAr(ev['attendance_level']?.toString()),
              ),
              _kv(
                'التحضير للواجبات',
                _toAr(ev['homework_preparation']?.toString()),
              ),
              _kv('المشاركة', _toAr(ev['participation_level']?.toString())),
              _kv(
                'اتباع التعليمات',
                _toAr(ev['instruction_following']?.toString()),
              ),
              const SizedBox(height: 8),
              if ((ev['guidance']?.toString().trim().isNotEmpty ?? false)) ...[
                const Text(
                  'التوجيه',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(ev['guidance'].toString()),
                const SizedBox(height: 8),
              ],
              if ((ev['notes']?.toString().trim().isNotEmpty ?? false)) ...[
                const Text(
                  'الملاحظات',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(ev['notes'].toString()),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String? v) {
    final val = (v == null || v.trim().isEmpty) ? '—' : v;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(val)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(title: 'تقييماتي', centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFrom,
                    icon: const Icon(Icons.date_range),
                    label: Text(_from != null ? _fmtYMD(_from!) : 'من تاريخ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTo,
                    icon: const Icon(Icons.date_range),
                    label: Text(_to != null ? _fmtYMD(_to!) : 'إلى تاريخ'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'مسح التصفية',
                  onPressed: (_from != null || _to != null)
                      ? _clearFilters
                      : null,
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
        padding: const EdgeInsets.all(16),
        children: const [Center(child: Text('لا توجد تقييمات'))],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          _fetch();
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final ev = _items[index];
        final date = _fmtDate(
          ev['eval_date']?.toString() ?? ev['date']?.toString(),
        );

        // مثال: نحدد لون البطاقة حسب المستوى العلمي
        final sci = ev['scientific_level']?.toString() ?? '';
        Color cardColor;
        if (sci == 'excellent') {
          cardColor = Colors.green.shade50;
        } else if (sci == 'weak') {
          cardColor = Colors.red.shade50;
        } else {
          cardColor = Colors.blueGrey.shade50;
        }

        return Card(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openDetails(ev),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // التاريخ + أيقونة
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        date.isNotEmpty ? date : '—',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_left, color: Colors.black54),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // الـ Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: -6,
                    children: [
                      _chip(
                        Icons.school,
                        'علمي',
                        _toAr(ev['scientific_level']?.toString()),
                      ),
                      _chip(
                        Icons.psychology,
                        'سلوكي',
                        _toAr(ev['behavioral_level']?.toString()),
                      ),
                      _chip(
                        Icons.access_time,
                        'حضوري',
                        _toAr(ev['attendance_level']?.toString()),
                      ),
                      _chip(
                        Icons.book,
                        'واجب',
                        _toAr(ev['homework_preparation']?.toString()),
                      ),
                      _chip(
                        Icons.group,
                        'مشاركة',
                        _toAr(ev['participation_level']?.toString()),
                      ),
                      _chip(
                        Icons.rule,
                        'تعليمات',
                        _toAr(ev['instruction_following']?.toString()),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // الملاحظات أو التوجيه بشكل مختصر
                  if ((ev['notes']?.toString().trim().isNotEmpty ?? false))
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.note_alt,
                            size: 18,
                            color: Colors.brown,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ev['notes'].toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(IconData icon, String label, String value) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      backgroundColor: Colors.blueAccent,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
