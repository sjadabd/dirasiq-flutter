import 'dart:convert';
import 'package:dirasiq/features/bookings/screens/booking_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/features/courses/screens/course_details_screen.dart';
import 'package:dirasiq/features/enrollments/screens/course_attendance_screen.dart';
import 'package:dirasiq/features/enrollments/screens/course_weekly_schedule_screen.dart';
import 'package:dirasiq/shared/widgets/global_app_bar.dart';
import 'package:dirasiq/core/services/notification_events.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:dirasiq/features/assignments/screens/student_assignments_screen.dart';
import 'package:dirasiq/features/assignments/screens/assignment_details_screen.dart';
import 'package:dirasiq/features/exams/screens/student_exams_screen.dart';
import 'package:dirasiq/features/exams/screens/student_exam_grades_screen.dart';
import 'package:dirasiq/features/evaluations/screens/student_evaluations_screen.dart';
import 'package:dirasiq/features/invoices/screens/invoice_details_screen.dart';

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
  StreamSubscription<void>? _notifSub;
  StreamSubscription<Map<String, dynamic>>? _payloadSub;
  String? _typeFilter;

  static const List<Map<String, String?>> _filters = [
    {"text": "الكل", "value": null},
    {"text": "واجب بيتي", "value": "homework"},
    {"text": "رسالة", "value": "message"},
    {"text": "تقرير", "value": "report"},
    {"text": "تبليغ", "value": "notice"},
    {"text": "أقساط", "value": "installments"},
    {"text": "حضور", "value": "attendance"},
    {"text": "ملخص درس اليومي", "value": "daily_summary"},
    {"text": "أعياد ميلاد", "value": "birthday"},
    {"text": "امتحان يومي", "value": "daily_exam"},
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
    _scroll.addListener(_onScroll);
    _notifSub = NotificationEvents.instance.onNewNotification.listen((_) async {
      try {
        final res = await _api.fetchMyNotifications(
          page: 1,
          limit: 1,
          type: _typeFilter,
        );
        final list = List<Map<String, dynamic>>.from(
          (res['items'] ?? res['notifications'] ?? res['data'] ?? []) as List,
        );
        if (list.isNotEmpty) {
          final latest = Map<String, dynamic>.from(list.first);
          final latestId = (latest['id'] ?? latest['_id'])?.toString();
          if (latestId != null && latestId.isNotEmpty) {
            final exists = _items.any(
              (e) => (e['id'] ?? e['_id']).toString() == latestId,
            );
            if (!exists && _matchesCurrentFilter(latest)) {
              if (!mounted) return;
              setState(() {
                _items.insert(0, latest);
                _hasMore = true;
                _loading = false;
                _error = null;
              });
            }
          }
        }
      } catch (_) {
        if (mounted) _fetch(refresh: true);
      }
    });

    _payloadSub = NotificationEvents.instance.onNotificationPayload.listen((n) {
      try {
        final id = (n['id'] ?? n['_id'] ?? n['notificationId'])?.toString();
        if (id == null || id.isEmpty) return;
        final exists = _items.any(
          (e) => (e['id'] ?? e['_id'] ?? e['notificationId']).toString() == id,
        );
        if (!exists && _matchesCurrentFilter(n)) {
          if (!mounted) return;
          setState(() {
            _items.insert(0, Map<String, dynamic>.from(n));
            _loading = false;
            _error = null;
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _notifSub?.cancel();
    _payloadSub?.cancel();
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

      final res = await _api.fetchMyNotifications(
        page: _page,
        limit: 10,
        type: _typeFilter,
      );
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
      setState(() {
        final idx = _items.indexWhere((e) => (e['id'] ?? e['_id']) == id);
        if (idx != -1) {
          _items[idx]['status'] = 'read';
          _items[idx]['isRead'] = true;
          _items[idx]['readAt'] = DateTime.now().toIso8601String();
        }
      });

      await _api.markNotificationAsRead(id);
      NotificationEvents.instance.emitNewNotification();
    } catch (_) {}
  }

  Future<void> _showNotificationDialog(Map<String, dynamic> n) async {
    final title = n['title']?.toString() ?? 'إشعار';
    final message = n['message']?.toString() ?? '';
    final createdAt = n['createdAt']?.toString();
    final time = _formatDate(createdAt);
    final payload = _parsePayload(n);
    final senderName = payload['sender'] is Map
        ? (payload['sender']['name']?.toString() ?? '')
        : '';
    final attachments = payload['attachments'] is Map
        ? Map<String, dynamic>.from(payload['attachments'])
        : <String, dynamic>{};
    final String? pdfUrl = (() {
      final raw = attachments['pdfUrl']?.toString();
      if (raw == null || raw.isEmpty) return null;
      return _resolveUrl(raw);
    })();
    final imageUrls = attachments['imageUrls'] is List
        ? List<String>.from(
            (attachments['imageUrls'] as List).map(
              (e) => _resolveUrl(e.toString()),
            ),
          )
        : <String>[];
    final String? link = (() {
      final raw = (payload['link'] ?? payload['url'])?.toString();
      if (raw == null || raw.isEmpty) return null;
      if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
      return _resolveUrl(raw);
    })();
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isNotEmpty) Text(message),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                if (senderName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('المرسل: $senderName'),
                ],
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'الصور',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final url = imageUrls[i];
                        return GestureDetector(
                          onTap: () => _openImagePreview(url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              height: 90,
                              width: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 90,
                                width: 90,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (pdfUrl != null && pdfUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'ملف PDF',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchUrl(pdfUrl),
                      icon: const Icon(Icons.picture_as_pdf, size: 20),
                      label: const Text('فتح ملف PDF'),
                    ),
                  ),
                ],
                if (link != null && link.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'رابط',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchUrl(link),
                      icon: const Icon(Icons.link, size: 20),
                      label: const Text('فتح الرابط'),
                    ),
                  ),
                ],
                if (studyYear != null && studyYear.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('السنة الدراسية: $studyYear'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openNotificationTarget(n);
              },
              icon: const Icon(Icons.open_in_new, size: 22),
              tooltip: 'عرض التفاصيل', // يظهر نص مساعد عند الوقوف على الأيقونة
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

    // Student evaluation routing
    final typeLower = type?.toLowerCase();
    final subType = (payload['subType'] ?? payload['sub_type'])?.toString().toLowerCase();
    final ratings = payload['ratings'] is Map ? Map<String, dynamic>.from(payload['ratings']) : <String, dynamic>{};
    final hasRatingsKeys = ratings.keys.any((k) => const {
          'scientific_level',
          'behavioral_level',
          'attendance_level',
          'homework_preparation',
          'participation_level',
          'instruction_following',
        }.contains(k));
    final isEvaluationNotification =
        (typeLower?.contains('evaluation') ?? false) ||
        subType == 'student_evaluation' ||
        payload.containsKey('scientific_level') ||
        payload.containsKey('behavioral_level') ||
        payload.containsKey('attendance_level') ||
        hasRatingsKeys;
    if (isEvaluationNotification) {
      final evaluationId = (payload['evaluationId'] ?? payload['evaluation_id'] ?? n['evaluationId'] ?? n['evaluation_id'])?.toString();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentEvaluationsScreen(
            initialEvaluationId: evaluationId,
          ),
        ),
      );
      return;
    }

    // Invoice routing (new invoice / payment reminder / installment updates)
    final invoiceId = (payload['invoiceId'] ?? payload['invoice_id'] ?? n['invoiceId'] ?? n['invoice_id'])?.toString();
    final isInvoiceBySubtype = subType == 'invoice_created' || subType == 'invoice_updated' || subType == 'installment_due' || subType == 'installment_paid';
    final isInvoiceByType = (typeLower?.contains('invoice') ?? false) || (typeLower == 'payment_reminder');
    if (invoiceId != null && invoiceId.isNotEmpty && (isInvoiceBySubtype || isInvoiceByType || true)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailsScreen(invoiceId: invoiceId),
        ),
      );
      return;
    }

    // Homework / Assignments routing
    if (typeLower != null && (typeLower.contains('assign') || typeLower.contains('homework'))) {
      final assignmentId = (payload['assignmentId'] ?? payload['assignment_id'] ?? n['assignmentId'] ?? n['assignment_id'])?.toString();
      if (assignmentId != null && assignmentId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AssignmentDetailsScreen(assignmentId: assignmentId),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const StudentAssignmentsScreen(),
          ),
        );
      }
      return;
    }

    // Exams routing (daily/monthly) — prioritize over course routing
    final payloadExamType = (payload['exam_type'] ?? payload['examType'] ?? payload['kind'] ?? n['exam_type'] ?? n['examType'])
        ?.toString()
        .toLowerCase();
    final isExamNotification = (typeLower?.contains('exam') ?? false) ||
        (payloadExamType == 'daily' || payloadExamType == 'monthly') ||
        ((payload['type'] ?? payload['category'])?.toString().toLowerCase() == 'exam');
    if (isExamNotification) {
      final isMonthly = payloadExamType == 'monthly' || typeLower == 'monthly_exam';

      if (isMonthly) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const StudentExamsScreen(fixedType: 'monthly', title: 'امتحانات شهرية'),
          ),
        );
        return;
      }
      // default to daily when unknown
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const StudentExamsScreen(fixedType: 'daily', title: 'امتحانات يومية'),
        ),
      );
      return;
    }

    // Exam grade routing — prioritize over course routing
    if (typeLower != null && (typeLower == 'exam_grade' || typeLower.contains('grade') || (payload['grade'] != null))) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const StudentExamGradesScreen(),
        ),
      );
      return;
    }

    if (type == 'course_update') {
      final courseId =
          (payload['courseId'] ??
                  payload['course_id'] ??
                  n['courseId'] ??
                  n['course_id'])
              ?.toString();
      final hasAttendanceMarkers =
          payload.containsKey('status') ||
          payload.containsKey('attendanceStatus') ||
          payload.containsKey('date') ||
          n.containsKey('status') ||
          n.containsKey('attendanceStatus') ||
          n.containsKey('date');
      if (courseId != null && courseId.isNotEmpty) {
        if (hasAttendanceMarkers) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseAttendanceScreen(courseId: courseId),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseWeeklyScheduleScreen(courseId: courseId),
            ),
          );
        }
        return;
      }
    }

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

    final courseIdFromPayload =
        (payload['courseId'] ??
                payload['course_id'] ??
                n['courseId'] ??
                n['course_id'])
            ?.toString();

    if (!isExamNotification && (
        type == 'new_course_available' ||
        type == 'course' ||
        type == 'open_course' ||
        courseIdFromPayload != null)) {
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

    final debugPayload = payload.isNotEmpty ? payload.toString() : n.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('لا توجد وجهة مخصصة لهذا الإشعار\n$debugPayload')),
    );
  }

  String _resolveUrl(String raw) {
    var s = raw.trim();
    s = s.replaceAll('\\', '/');
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('./')) s = s.substring(2);
    final base = ApiService.getBaseUrl().replaceAll(RegExp(r"/+$"), '');
    if (s.startsWith('/')) {
      return '$base$s';
    } else {
      return '$base/${s.replaceFirst(RegExp(r"^/+"), '')}';
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط')));
    }
  }

  Future<void> _openImagePreview(String url) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey.shade300,
              child: const Center(child: Icon(Icons.broken_image, size: 48)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const GlobalAppBar(title: 'الإشعارات', centerTitle: true),
      body: Column(
        children: [
          _filtersChips(scheme),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetch(refresh: true),
              child: _buildBody(scheme),
            ),
          ),
        ],
      ),
    );
  }

  String? _canonicalType(Map<String, dynamic> n) {
    final rawType =
        (n['type'] ??
                n['category'] ??
                n['event'] ??
                n['notificationType'] ??
                n['template'] ??
                n['action'])
            ?.toString()
            .toLowerCase();
    if (rawType == null || rawType.isEmpty) return null;

    final payload = _parsePayload(n);
    final hasAttendanceMarkers =
        payload.containsKey('status') ||
        payload.containsKey('attendanceStatus') ||
        payload.containsKey('date') ||
        n.containsKey('status') ||
        n.containsKey('attendanceStatus') ||
        n.containsKey('date');
    if (rawType == 'course_update' && hasAttendanceMarkers) return 'attendance';

    return rawType;
  }

  bool _matchesCurrentFilter(Map<String, dynamic> n) {
    if (_typeFilter == null) return true;
    final t = _canonicalType(n);
    return t == _typeFilter;
  }

  Widget _filtersChips(ColorScheme scheme) {
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (final f in _filters) ...[
              _buildChip(f, scheme),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(Map<String, String?> f, ColorScheme scheme) {
    final val = f['value'];
    final selected = _typeFilter == val;
    return ChoiceChip(
      label: Text(f['text'] ?? ''),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _typeFilter = val;
        });
        _fetch(refresh: true);
      },
      selectedColor: scheme.primary.withOpacity(.12),
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outlineVariant,
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          Center(child: Text('لا توجد إشعارات لهذا الفلتر حالياً')),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 8),
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
        final payload = _parsePayload(n);
        final senderName = payload['sender'] is Map
            ? (payload['sender']['name']?.toString() ?? '')
            : '';
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
            subtitle: (message.isNotEmpty || senderName.isNotEmpty)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isNotEmpty)
                        Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (senderName.isNotEmpty)
                        Text(
                          'المرسل: $senderName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.outline),
                        ),
                    ],
                  )
                : null,
            trailing: Text(time, style: TextStyle(color: scheme.outline)),
            onTap: () {
              final idx = _items.indexWhere((e) => (e['id'] ?? e['_id']) == id);
              if (idx != -1) {
                final current = _items[idx];

                final alreadyRead =
                    current['isRead'] == true ||
                    current['readAt'] != null ||
                    current['status'] == 'read';

                if (!alreadyRead) {
                  setState(() {
                    _items[idx]['status'] = 'read';
                    _items[idx]['isRead'] = true;
                    _items[idx]['readAt'] = DateTime.now().toIso8601String();
                  });

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
