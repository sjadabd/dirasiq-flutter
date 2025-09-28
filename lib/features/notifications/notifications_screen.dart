import 'dart:convert';
import 'package:dirasiq/features/bookings/screens/booking_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/features/courses/screens/course_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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
    _fetch();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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

      if (!_hasMore && !refresh) return;

      final res = await _api.fetchMyNotifications(page: _page, limit: 10);
      final List<dynamic> list =
          res['items'] ?? res['notifications'] ?? res['data'] ?? [];
      final total = res['total'] ?? 0;

      setState(() {
        final pageItems = List<Map<String, dynamic>>.from(list);
        _items.addAll(pageItems);
        _loading = false;
        _hasMore =
            _items.length <
            (total is int ? total : _items.length + pageItems.length);
        if (_hasMore) _page += 1;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      if (!_loading && _hasMore) {
        _fetch();
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _api.markNotificationAsRead(id);
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((e) => (e['id'] ?? e['_id']) == id);
        if (idx != -1) {
          _items[idx]['status'] = 'read';
        }
      });
    } catch (_) {}
  }

  Future<void> _showNotificationDialog(Map<String, dynamic> n) async {
    final title = n['title']?.toString() ?? 'إشعار';
    final message = n['message']?.toString() ?? '';
    final createdAt = n['createdAt']?.toString();
    final time = _formatDate(createdAt);
    final payload = _parsePayload(n);
    final studyYear =
        (payload['studyYear'] ??
                payload['study_year'] ??
                n['studyYear'] ??
                n['study_year'])
            ?.toString();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.isNotEmpty) Text(message),
              const SizedBox(height: 8),
              Text(
                time,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              if (studyYear != null && studyYear.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('السنة الدراسية: $studyYear'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openNotificationTarget(n);
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('عرض التفاصيل'),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic> _parsePayload(Map<String, dynamic> n) {
    Map<String, dynamic> payload = {};
    dynamic raw =
        n['payload'] ??
        n['data'] ??
        n['additionalData'] ??
        n['meta'] ??
        n['extra'];
    Map<String, dynamic>? tryParse(String s) {
      try {
        final trimmed = s.trim();
        final decoded = jsonDecode(trimmed);
        if (decoded is String) {
          final decoded2 = jsonDecode(decoded);
          if (decoded2 is Map<String, dynamic>) return decoded2;
        }
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
      return null;
    }

    if (raw is Map<String, dynamic>) {
      payload = raw;
    } else if (raw is String && raw.isNotEmpty) {
      payload = tryParse(raw) ?? {};
    }

    if (payload.isEmpty) {
      final keys = [
        'courseId',
        'course_id',
        'gradeId',
        'grade_id',
        'studyYear',
        'study_year',
      ];
      for (final k in keys) {
        if (n[k] != null) payload[k] = n[k];
      }
    }
    return payload;
  }

  void _openNotificationTarget(Map<String, dynamic> n) {
    final type =
        (n['type'] ??
                n['category'] ??
                n['event'] ??
                n['notificationType'] ??
                n['template'] ??
                n['action'])
            ?.toString();

    final payload = _parsePayload(n);

    // ✅ إذا الإشعار يخص الحجز
    if (type == 'booking_status') {
      final bookingId =
          (payload['bookingId'] ??
                  payload['booking_id'] ??
                  n['bookingId'] ??
                  n['booking_id'])
              ?.toString();
      if (bookingId != null && bookingId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailsScreen(bookingId: bookingId),
          ),
        );
        return;
      }
    }

    // ✅ إذا الإشعار يخص الكورسات
    final courseIdFromPayload =
        (payload['courseId'] ??
                payload['course_id'] ??
                n['courseId'] ??
                n['course_id'])
            ?.toString();

    if (type == 'new_course_available' ||
        type == 'course' ||
        type == 'open_course' ||
        courseIdFromPayload != null) {
      final courseId = courseIdFromPayload;
      if (courseId != null && courseId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourseDetailsScreen(courseId: courseId),
          ),
        );
        return;
      }
    }

    // fallback
    final debugPayload = payload.isNotEmpty ? payload.toString() : n.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('لا توجد وجهة مخصصة لهذا الإشعار\n$debugPayload')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: RefreshIndicator(
        onRefresh: () => _fetch(refresh: true),
        child: _buildBody(scheme),
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      // اجعل الحالة قابلة للسحب للتحديث
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
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
      // قائمة فارغة لكن قابلة للسحب للتحديث
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Center(child: Text('لا توجد إشعارات حالياً')),
        ],
      );
    }


    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final n = _items[index];
        final id = (n['id'] ?? n['_id'])?.toString() ?? '';
        final title = n['title']?.toString() ?? 'إشعار';
        final message = n['message']?.toString() ?? '';
        final status = n['status']?.toString() ?? 'sent';
        final isReadFlag = n['isRead'] == true;
        final readAtVal = n['readAt'];
        final createdAt = n['createdAt']?.toString();
        final time = _formatDate(createdAt);

        final isUnread = !(isReadFlag || readAtVal != null || status == 'read');

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isUnread
                  ? scheme.primary.withOpacity(.15)
                  : scheme.surfaceContainerHighest,
              child: Icon(
                isUnread
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: isUnread ? scheme.primary : scheme.outline,
              ),
            ),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(time, style: TextStyle(color: scheme.outline)),
            onTap: () {
              final idx = _items.indexWhere((e) => (e['id'] ?? e['_id']) == id);
              if (idx != -1) {
                final current = _items[idx];

                // ✅ تحقق إذا الإشعار مقروء بالفعل
                final alreadyRead =
                    current['isRead'] == true ||
                    current['readAt'] != null ||
                    current['status'] == 'read';

                if (!alreadyRead) {
                  // حدّث الواجهة فوراً
                  setState(() {
                    _items[idx]['status'] = 'read';
                    _items[idx]['isRead'] = true;
                    _items[idx]['readAt'] = DateTime.now().toIso8601String();
                  });

                  // أرسل إلى الخادم مرة وحدة فقط
                  _markAsRead(id);
                }
              }

              _showNotificationDialog(n);
            },
          ),
        );
      },
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM HH:mm').format(d);
    } catch (_) {
      return '';
    }
  }
}
