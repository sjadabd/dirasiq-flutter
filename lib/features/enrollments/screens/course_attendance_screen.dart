import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mulhimiq/shared/widgets/global_app_bar.dart';
import 'package:mulhimiq/shared/themes/app_colors.dart';
import 'package:mulhimiq/core/services/api_service.dart';

class CourseAttendanceScreen extends StatefulWidget {
  final String courseId;
  final String? courseName;

  const CourseAttendanceScreen({
    super.key,
    required this.courseId,
    this.courseName,
  });

  @override
  State<CourseAttendanceScreen> createState() => _CourseAttendanceScreenState();
}

class _CourseAttendanceScreenState extends State<CourseAttendanceScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _filter = 'all'; // all, present, absent, leave

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
      final res = await _api.fetchMyAttendanceByCourse(widget.courseId);
      final dynamic rawItems =
          res['items'] ??
          res['records'] ??
          res['attendance'] ??
          res['data'] ??
          res;
      final list = (rawItems is List) ? rawItems : [];
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          list.map((e) => Map<String, dynamic>.from(e as Map)),
        );
        _loading = false;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.courseName ?? 'سجل الحضور';
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: GlobalAppBar(title: title, centerTitle: true),
      body: RefreshIndicator(onRefresh: _fetch, child: _buildBody(isDark)),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.error_outline, color: AppColors.error, size: 32),
          const SizedBox(height: 6),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          Center(
            child: ElevatedButton(
              onPressed: _fetch,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 32),
              ),
              child: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      );
    }

    final counts = _computeCounts(_items);
    final filtered = _filteredItems();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        _summaryRow(counts, isDark),
        const SizedBox(height: 10),
        _filterChips(counts, isDark),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          Card(
            elevation: 0,
            color: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.08,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  _filter == 'all'
                      ? 'لا توجد سجلات حالياً'
                      : 'لا توجد سجلات لهذه الحالة',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
          )
        else
          ...filtered.map((item) => _attendanceTile(item, isDark)),
      ],
    );
  }

  Map<String, int> _computeCounts(List<Map<String, dynamic>> list) {
    int present = 0, absent = 0, leave = 0;
    for (final r in list) {
      final s = (r['status'] ?? r['attendanceStatus'] ?? r['type'] ?? '')
          .toString()
          .toLowerCase();
      if (s.contains('present') || s == 'حضور' || s == 'presented') {
        present++;
      } else if (s.contains('absent') || s == 'غياب') {
        absent++;
      } else if (s.contains('leave') || s == 'اجازة' || s == 'إجازة') {
        leave++;
      }
    }
    return {
      'total': list.length,
      'present': present,
      'absent': absent,
      'leave': leave,
    };
  }

  List<Map<String, dynamic>> _filteredItems() {
    if (_filter == 'all') return _sorted(_items);
    return _sorted(
      _items.where((r) {
        final s = (r['status'] ?? r['attendanceStatus'] ?? r['type'] ?? '')
            .toString()
            .toLowerCase();
        if (_filter == 'present') {
          return s.contains('present') || s == 'حضور' || s == 'presented';
        }
        if (_filter == 'absent') return s.contains('absent') || s == 'غياب';
        if (_filter == 'leave') {
          return s.contains('leave') || s == 'اجازة' || s == 'إجازة';
        }
        return true;
      }).toList(),
    );
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> list) {
    final copy = [...list];
    copy.sort((a, b) {
      final ad = _parseDate(
        a['checkin_at'] ??
            a['occurred_on'] ??
            a['date'] ??
            a['sessionDate'] ??
            a['createdAt'],
      );
      final bd = _parseDate(
        b['checkin_at'] ??
            b['occurred_on'] ??
            b['date'] ??
            b['sessionDate'] ??
            b['createdAt'],
      );
      return bd.compareTo(ad); // latest first
    });
    return copy;
  }

  DateTime _parseDate(dynamic v) {
    try {
      if (v == null) return DateTime.fromMicrosecondsSinceEpoch(0);
      final s = v.toString();
      if (s.length <= 10 && s.contains('-')) {
        return DateTime.parse(s);
      }
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.fromMicrosecondsSinceEpoch(0);
    }
  }

  Widget _summaryRow(Map<String, int> c, bool isDark) {
    return Row(
      children: [
        _summaryCard(
          icon: Icons.check_circle,
          label: 'حضور',
          value: c['present'] ?? 0,
          color: AppColors.success,
          isDark: isDark,
        ),
        const SizedBox(width: 6),
        _summaryCard(
          icon: Icons.cancel,
          label: 'غياب',
          value: c['absent'] ?? 0,
          color: AppColors.error,
          isDark: isDark,
        ),
        const SizedBox(width: 6),
        _summaryCard(
          icon: Icons.event_busy,
          label: 'إجازة',
          value: c['leave'] ?? 0,
          color: AppColors.warning,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.08,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.03),
                color.withValues(alpha: 0.01),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
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
  }

  Widget _filterChips(Map<String, int> c, bool isDark) {
    Widget chip(String key, String label, {IconData? icon}) {
      final selected = _filter == key;
      return GestureDetector(
        onTap: () => setState(() => _filter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.tertiary.withValues(alpha: 0.1)
                : (isDark ? AppColors.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.tertiary
                  : (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.1,
                    ),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: selected
                      ? AppColors.tertiary
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? AppColors.tertiary
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip('all', 'الكل', icon: Icons.list_alt),
        chip('present', 'الحضور', icon: Icons.check_circle),
        chip('absent', 'الغياب', icon: Icons.cancel),
        chip('leave', 'الإجازات', icon: Icons.event_busy),
      ],
    );
  }

  Widget _attendanceTile(Map<String, dynamic> r, bool isDark) {
    final statusRaw = (r['status'] ?? r['attendanceStatus'] ?? r['type'] ?? '')
        .toString()
        .toLowerCase();
    String title;
    IconData icon;
    Color color;

    if (statusRaw.contains('present') ||
        statusRaw == 'حضور' ||
        statusRaw == 'presented') {
      title = 'حضور';
      icon = Icons.check_circle;
      color = AppColors.success;
    } else if (statusRaw.contains('absent') || statusRaw == 'غياب') {
      title = 'غياب';
      icon = Icons.cancel;
      color = AppColors.error;
    } else if (statusRaw.contains('leave') ||
        statusRaw == 'اجازة' ||
        statusRaw == 'إجازة') {
      title = 'إجازة';
      icon = Icons.event_busy;
      color = AppColors.warning;
    } else {
      title = statusRaw.isEmpty ? 'غير محدد' : statusRaw;
      icon = Icons.help_outline;
      color = AppColors.primary;
    }

    final occurredRaw =
        r['occurred_on'] ?? r['date'] ?? r['sessionDate'] ?? r['createdAt'];
    final checkinRaw = r['checkin_at'];
    final checkin12hRaw = r['checkin_at_12h'];
    final occurred = _safeFormatDateDay(occurredRaw?.toString());
    final checkin =
        (checkin12hRaw != null && checkin12hRaw.toString().isNotEmpty)
        ? checkin12hRaw.toString()
        : _safeFormatDateTime(checkinRaw?.toString());
    final sessionTitle =
        (r['sessionTitle'] ?? r['title'] ?? r['session']?['title'] ?? '')
            .toString();
    final notes = (r['notes'] ?? r['reason'] ?? '').toString();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.03),
              color.withValues(alpha: 0.01),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          title: Text(
            sessionTitle.isNotEmpty ? sessionTitle : title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sessionTitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 9, color: color),
                  ),
                ),
              ],
              if (occurred.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 10,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      occurred,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
              if (checkin.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 10,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      checkin,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.03,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.note,
                        size: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          notes,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.black54,
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
    );
  }

  String _safeFormatDateDay(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      if (iso.length <= 10) {
        final d = DateTime.parse(iso).toLocal();
        return DateFormat('dd/MM/yyyy').format(d);
      }
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return '';
    }
  }

  String _safeFormatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('HH:mm').format(d);
    } catch (_) {
      return '';
    }
  }
}
