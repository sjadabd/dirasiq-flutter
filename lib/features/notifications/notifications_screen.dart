import 'dart:convert';
import 'package:mulhimiq/features/bookings/screens/booking_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mulhimiq/core/services/api_service.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mulhimiq/features/courses/screens/course_details_screen.dart';
import 'package:mulhimiq/features/enrollments/screens/course_attendance_screen.dart';
import 'package:mulhimiq/features/enrollments/screens/course_weekly_schedule_screen.dart';
import 'package:mulhimiq/shared/design_system/design_system.dart';
import 'package:mulhimiq/core/services/notification_events.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:mulhimiq/features/assignments/screens/student_assignments_screen.dart';
import 'package:mulhimiq/features/assignments/screens/assignment_details_screen.dart';
import 'package:mulhimiq/features/exams/screens/student_exams_screen.dart';
import 'package:mulhimiq/features/exams/screens/student_exam_grades_screen.dart';
import 'package:mulhimiq/features/evaluations/screens/student_evaluations_screen.dart';
import 'package:mulhimiq/features/invoices/screens/invoice_details_screen.dart';
import 'package:mulhimiq/features/teacher/shared/teacher_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // Role drives booking-notification routing: a teacher goes to the bookings
  // screen, a student to that booking's details.
  bool _isTeacher = false;

  static const List<Map<String, dynamic>> _filters = [
    {"text": "الكل", "value": null, "icon": Icons.notifications_rounded},
    {
      "text": "واجب",
      "value": "assignment_due",
      "icon": Icons.assignment_rounded,
    },
    {
      "text": "امتحان جديد",
      "value": "class_reminder",
      "icon": Icons.quiz_rounded,
    },
    {
      "text": "نتيجة امتحان",
      "value": "grade_update",
      "icon": Icons.fact_check_rounded,
    },
    {
      "text": "الدروس والحضور",
      "value": "COURSE_UPDATE",
      "icon": Icons.event_available_rounded,
    },
    {
      "text": "المدفوعات",
      "value": "PAYMENT_REMINDER",
      "icon": Icons.payments_rounded,
    },
    {
      "text": "رسالة معلم",
      "value": "teacher_message",
      "icon": Icons.sms_rounded,
    },
    {
      "text": "إعلان النظام",
      "value": "SYSTEM_ANNOUNCEMENT",
      "icon": Icons.campaign_rounded,
    },
    {
      "text": "حجز دورة",
      "value": "booking_status",
      "icon": Icons.event_note_rounded,
    },
  ];
  @override
  void initState() {
    super.initState();
    _loadRole();
    _fetch();
    _scroll.addListener(_onScroll);
    _setupNotificationListeners();
  }

  Future<void> _loadRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user');
      if (raw == null) return;
      final u = jsonDecode(raw) as Map<String, dynamic>;
      final t = (u['userType'] ?? u['user_type'] ?? u['type'])
          ?.toString()
          .toLowerCase();
      if (mounted) setState(() => _isTeacher = t == 'teacher');
    } catch (_) {}
  }

  void _setupNotificationListeners() {
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = n['title']?.toString() ?? 'إشعار';
    final message = n['message']?.toString() ?? '';
    final createdAt =
        (n['createdAt']?.toString() ??
        n['created_at']?.toString() ??
        n['timestamp']?.toString() ??
        n['time']?.toString() ??
        _parsePayload(n)['createdAt']?.toString() ??
        _parsePayload(n)['created_at']?.toString());
    final time = createdAt != null ? _formatDate(createdAt) : '';
    final payload = _parsePayload(n);
    final senderName = payload['sender'] is Map
        ? (payload['sender']['name']?.toString() ?? '')
        : '';
    // Parse attachments from data or payload
    final attachments = (payload['attachments'] ?? n['attachments']) is Map
        ? Map<String, dynamic>.from(payload['attachments'] ?? n['attachments'])
        : <String, dynamic>{};

    // Extract PDF URLs
    final List<String> pdfUrls = [];
    final pdfUrl = attachments['pdfUrl']?.toString();
    if (pdfUrl != null && pdfUrl.isNotEmpty) {
      pdfUrls.add(_resolveUrl(pdfUrl));
    }

    // Extract files array for additional PDFs and images
    final files = attachments['files'] is List
        ? List<dynamic>.from(attachments['files'])
        : [];
    for (final file in files) {
      if (file is Map) {
        final fileUrl = file['url']?.toString();
        final fileName = file['name']?.toString() ?? '';
        if (fileUrl != null &&
            fileUrl.isNotEmpty &&
            fileName.toLowerCase().endsWith('.pdf')) {
          pdfUrls.add(_resolveUrl(fileUrl));
        }
      }
    }

    // Extract image URLs
    final imageUrls = attachments['imageUrls'] is List
        ? List<String>.from(
            (attachments['imageUrls'] as List).map(
              (e) => _resolveUrl(e.toString()),
            ),
          )
        : <String>[];

    // Add images from files if present
    for (final file in files) {
      if (file is Map) {
        final url = file['url']?.toString();
        final name = (file['name'] ?? '').toString().toLowerCase();
        final type = (file['type'] ?? file['mime'] ?? file['mimetype'] ?? '')
            .toString()
            .toLowerCase();
        final isImage =
            type.startsWith('image/') ||
            type == 'image' ||
            name.endsWith('.png') ||
            name.endsWith('.jpg') ||
            name.endsWith('.jpeg') ||
            name.endsWith('.webp') ||
            name.endsWith('.gif');
        if (isImage && url != null && url.isNotEmpty) {
          imageUrls.add(_resolveUrl(url));
        }
      }
    }

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

    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return Theme(
          data: dsTheme,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(builder: (context) {
              final m = context.mq;
              return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            decoration: BoxDecoration(
              color: m.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact Header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: m.accent,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
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
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.isNotEmpty) ...[
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: m.accent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),

                        if (senderName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 13,
                                color: m.accent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'المرسل: $senderName',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Display Images Inline
                        if (imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.image_rounded,
                                size: 15,
                                color: m.orange,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'الصور المرفقة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: imageUrls.length,
                            itemBuilder: (_, i) {
                              final url = imageUrls[i];
                              return GestureDetector(
                                onTap: () => _openImagePreview(url),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: m.accent.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (_, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              value:
                                                  progress.expectedTotalBytes !=
                                                      null
                                                  ? progress.cumulativeBytesLoaded /
                                                        progress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, _, _) => Container(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        child: Icon(
                                          Icons.broken_image,
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],

                        // Display PDF Buttons
                        if (pdfUrls.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 15,
                                color: m.error,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'ملفات PDF',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...pdfUrls.asMap().entries.map((entry) {
                            final index = entry.key;
                            final pdfUrl = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _buildCompactPdfButton(
                                pdfUrl: pdfUrl,
                                label: pdfUrls.length > 1
                                    ? 'ملف PDF ${index + 1}'
                                    : 'فتح ملف PDF',
                                m: m,
                              ),
                            );
                          }),
                        ],

                        if (link != null && link.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildCompactLinkButton(link: link, m: m),
                        ],

                        if (studyYear != null && studyYear.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: m.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.school_rounded,
                                  size: 14,
                                  color: m.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'السنة: $studyYear',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: m.accent,
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

                // Compact Actions
                Padding(
                  padding: const EdgeInsets.all(MqSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: MqButton(
                          label: 'إغلاق',
                          variant: MqButtonVariant.secondary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      MqSpacing.gapSm,
                      Expanded(
                        child: MqButton(
                          label: 'التفاصيل',
                          onPressed: () {
                            Navigator.of(context).pop();
                            _openNotificationTarget(n);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
            }),
          ),
        );
      },
    );
  }

  Widget _buildCompactPdfButton({
    required String pdfUrl,
    required String label,
    required MqColors m,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchUrl(pdfUrl),
        borderRadius: MqRadius.brMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: m.error.withValues(alpha: 0.1),
            borderRadius: MqRadius.brMd,
            border: Border.all(color: m.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf_rounded, size: 16, color: m.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: m.error),
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 14, color: m.error),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactLinkButton({
    required String link,
    required MqColors m,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchUrl(link),
        borderRadius: MqRadius.brMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: m.accent.withValues(alpha: 0.1),
            borderRadius: MqRadius.brMd,
            border: Border.all(color: m.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, size: 16, color: m.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'فتح الرابط',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: m.accent),
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 14, color: m.accent),
            ],
          ),
        ),
      ),
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
    final subType = (payload['subType'] ?? payload['sub_type'])
        ?.toString()
        .toLowerCase();
    final ratings = payload['ratings'] is Map
        ? Map<String, dynamic>.from(payload['ratings'])
        : <String, dynamic>{};
    final hasRatingsKeys = ratings.keys.any(
      (k) => const {
        'scientific_level',
        'behavioral_level',
        'attendance_level',
        'homework_preparation',
        'participation_level',
        'instruction_following',
      }.contains(k),
    );
    final isEvaluationNotification =
        (typeLower?.contains('evaluation') ?? false) ||
        subType == 'student_evaluation' ||
        payload.containsKey('scientific_level') ||
        payload.containsKey('behavioral_level') ||
        payload.containsKey('attendance_level') ||
        hasRatingsKeys;

    if (isEvaluationNotification) {
      final evaluationId =
          (payload['evaluationId'] ??
                  payload['evaluation_id'] ??
                  n['evaluationId'] ??
                  n['evaluation_id'])
              ?.toString();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              StudentEvaluationsScreen(initialEvaluationId: evaluationId),
        ),
      );
      return;
    }

    // Invoice routing
    final invoiceId =
        (payload['invoiceId'] ??
                payload['invoice_id'] ??
                n['invoiceId'] ??
                n['invoice_id'])
            ?.toString();
    final isInvoiceBySubtype =
        subType == 'invoice_created' ||
        subType == 'invoice_updated' ||
        subType == 'installment_due' ||
        subType == 'installment_paid';
    final isInvoiceByType =
        (typeLower?.contains('invoice') ?? false) ||
        (typeLower == 'payment_reminder');

    if (invoiceId != null &&
        invoiceId.isNotEmpty &&
        (isInvoiceBySubtype || isInvoiceByType || true)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailsScreen(invoiceId: invoiceId),
        ),
      );
      return;
    }

    // Homework / Assignments routing
    if (typeLower != null &&
        (typeLower.contains('assign') || typeLower.contains('homework'))) {
      final assignmentId =
          (payload['assignmentId'] ??
                  payload['assignment_id'] ??
                  n['assignmentId'] ??
                  n['assignment_id'])
              ?.toString();
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
          MaterialPageRoute(builder: (_) => const StudentAssignmentsScreen()),
        );
      }
      return;
    }

    // Exams routing
    final payloadExamType =
        (payload['exam_type'] ??
                payload['examType'] ??
                payload['kind'] ??
                n['exam_type'] ??
                n['examType'])
            ?.toString()
            .toLowerCase();
    final isExamNotification =
        (typeLower?.contains('exam') ?? false) ||
        (payloadExamType == 'daily' || payloadExamType == 'monthly') ||
        ((payload['type'] ?? payload['category'])?.toString().toLowerCase() ==
            'exam');

    if (isExamNotification) {
      final isMonthly =
          payloadExamType == 'monthly' || typeLower == 'monthly_exam';
      if (isMonthly) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const StudentExamsScreen(
              fixedType: 'monthly',
              title: 'امتحانات شهرية',
            ),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const StudentExamsScreen(
            fixedType: 'daily',
            title: 'امتحانات يومية',
          ),
        ),
      );
      return;
    }

    // Exam grade routing
    if (typeLower != null &&
        (typeLower == 'exam_grade' ||
            typeLower.contains('grade') ||
            (payload['grade'] != null))) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StudentExamGradesScreen()),
      );
      return;
    }

    // Course update routing
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

    // Booking routing — role-aware. A teacher receives a booking REQUEST
    // ('new_booking') and must land on the teacher bookings screen; a student
    // receives a 'booking_status' update and should see that booking's details.
    final isBooking = type == 'booking_status' ||
        type == 'new_booking' ||
        type == 'booking' ||
        (type?.toLowerCase().contains('booking') ?? false);
    if (isBooking) {
      if (_isTeacher) {
        TeacherWorkspace.jumpTo(context, TeacherWorkspaceState.bookingsIdx);
        return;
      }
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

    // Course details routing
    final courseIdFromPayload =
        (payload['courseId'] ??
                payload['course_id'] ??
                n['courseId'] ??
                n['course_id'])
            ?.toString();
    if (!isExamNotification &&
        (type == 'new_course_available' ||
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('لا توجد وجهة مخصصة لهذا الإشعار'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تعذر فتح الرابط'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تعذر فتح الرابط'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _openImagePreview(String url) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.grey.shade300,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dsTheme = isDark ? MqTheme.dark() : MqTheme.light();

    return Theme(
      data: dsTheme,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.mq.page,
            appBar: AppBar(
              title: const Text('الإشعارات'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: MqSpacing.sm),
                  child: Text('تابع آخر التحديثات والتنبيهات', style: context.text.bodySmall),
                ),
              ),
            ),
            body: Column(
              children: [
                _filtersRow(context),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _fetch(refresh: true),
                    child: _buildBody(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filtersRow(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.mq.page,
        border: Border(bottom: BorderSide(color: context.mq.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: MqSpacing.sm),
      child: SizedBox(
        height: MqSize.chipHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: MqSpacing.lg),
          itemCount: _filters.length,
          separatorBuilder: (_, _) => const SizedBox(width: MqSpacing.xs),
          itemBuilder: (_, i) {
            final f = _filters[i];
            return MqChip(
              label: (f['text'] ?? '').toString(),
              icon: f['icon'] as IconData?,
              selected: _typeFilter == f['value'],
              onTap: () {
                setState(() => _typeFilter = f['value'] as String?);
                _fetch(refresh: true);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _items.isEmpty) return _buildSkeleton(context);
    if (_error != null && _items.isEmpty) return _buildError(context);
    if (_items.isEmpty) return _buildEmpty(context);

    final groups = _groupedSections();
    final children = <Widget>[];
    for (final g in groups) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(MqSpacing.xs, MqSpacing.md, MqSpacing.xs, MqSpacing.sm),
        child: Row(
          children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: context.mq.accent, borderRadius: MqRadius.brPill)),
            MqSpacing.gapSm,
            Text(g.title, style: context.text.titleSmall),
            MqSpacing.gapXs,
            MqBadge(label: '${g.items.length}', tone: MqBadgeTone.neutral),
          ],
        ),
      ));
      for (final n in g.items) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: MqSpacing.sm),
          child: _notificationCard(context, n),
        ));
      }
    }
    if (_hasMore) {
      children.add(const Padding(
        padding: EdgeInsets.all(MqSpacing.md),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ));
    }

    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.sm, MqSpacing.lg, MqSpacing.xxxl),
      children: children,
    );
  }

  Widget _buildError(BuildContext context) {
    final mq = context.mq;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        MqCard(
          padding: const EdgeInsets.all(MqSpacing.xl),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(MqSpacing.md),
                decoration: BoxDecoration(color: mq.error.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.wifi_off_rounded, size: 32, color: mq.error),
              ),
              MqSpacing.gapMd,
              Text('تعذّر تحميل الإشعارات', style: context.text.titleMedium),
              MqSpacing.gapSm,
              MqButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expand: false, onPressed: () => _fetch(refresh: true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final mq = context.mq;
    final filtered = _typeFilter != null;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MqSpacing.lg),
      children: [
        const SizedBox(height: MqSpacing.xxl),
        MqCard(
          padding: const EdgeInsets.all(MqSpacing.xl),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(MqSpacing.lg),
                decoration: BoxDecoration(color: mq.accentSoft, shape: BoxShape.circle),
                child: Icon(Icons.notifications_off_outlined, size: 44, color: mq.accent),
              ),
              MqSpacing.gapMd,
              Text(filtered ? 'لا توجد إشعارات لهذا الفلتر' : 'لا توجد إشعارات بعد',
                  style: context.text.titleMedium, textAlign: TextAlign.center),
              MqSpacing.gapXs,
              Text('ستظهر هنا تنبيهات محاضراتك واختباراتك ودرجاتك.',
                  style: context.text.bodySmall, textAlign: TextAlign.center),
              MqSpacing.gapMd,
              if (filtered)
                MqButton.tonal(
                  label: 'عرض كل الإشعارات',
                  expand: false,
                  onPressed: () {
                    setState(() => _typeFilter = null);
                    _fetch(refresh: true);
                  },
                )
              else
                MqButton(
                  label: 'العودة للرئيسية',
                  icon: Icons.home_outlined,
                  expand: false,
                  onPressed: () => Get.back(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final mq = context.mq;
    Widget bar(double w, double h) => Container(
          width: w, height: h,
          decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brSm),
        );
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(MqSpacing.lg, MqSpacing.lg, MqSpacing.lg, MqSpacing.lg),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: MqSpacing.sm),
      itemBuilder: (_, _) => MqCard(
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: mq.fill2, borderRadius: MqRadius.brMd)),
            MqSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [bar(160, 12), const SizedBox(height: 8), bar(220, 10), const SizedBox(height: 8), bar(90, 9)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({IconData icon, Color color, String label}) _typeStyle(BuildContext context, Map<String, dynamic> n) {
    final mq = context.mq;
    final t = (_canonicalType(n) ?? '').toLowerCase();
    bool has(String s) => t.contains(s);
    if (has('assign') || has('homework')) return (icon: Icons.assignment_rounded, color: mq.accent, label: 'واجب');
    if (has('grade') || t == 'exam_grade' || has('result')) return (icon: Icons.fact_check_rounded, color: mq.success, label: 'نتيجة');
    if (has('exam') || t == 'class_reminder' || has('quiz')) return (icon: Icons.quiz_rounded, color: mq.accent, label: 'اختبار');
    if (has('message') || has('chat') || t == 'teacher_message') return (icon: Icons.forum_rounded, color: mq.accent, label: 'رسالة');
    if (has('payment') || has('invoice') || has('installment')) return (icon: Icons.payments_rounded, color: mq.orange, label: 'دفع');
    if (has('attendance') || has('course_update') || has('session') || has('lecture')) return (icon: Icons.event_available_rounded, color: mq.accent, label: 'محاضرة');
    if (has('booking')) return (icon: Icons.event_note_rounded, color: mq.accent, label: 'حجز');
    if (has('system') || has('announcement') || has('news')) return (icon: Icons.campaign_rounded, color: mq.orange, label: 'إعلان');
    return (icon: Icons.notifications_rounded, color: mq.accent, label: 'إشعار');
  }

  DateTime? _notifDate(Map<String, dynamic> n) {
    final raw = n['createdAt']?.toString() ??
        n['created_at']?.toString() ??
        n['timestamp']?.toString() ??
        n['time']?.toString() ??
        _parsePayload(n)['createdAt']?.toString() ??
        _parsePayload(n)['created_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  bool _isUnread(Map<String, dynamic> n) {
    final status = n['status']?.toString() ?? 'sent';
    return !(n['isRead'] == true || n['readAt'] != null || status == 'read');
  }

  /// Groups [_items] into اليوم / أمس / هذا الأسبوع / الأقدم, preserving order
  /// and dropping empty buckets.
  List<({String title, List<Map<String, dynamic>> items})> _groupedSections() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(const Duration(days: 7));

    final order = ['اليوم', 'أمس', 'هذا الأسبوع', 'الأقدم'];
    final buckets = <String, List<Map<String, dynamic>>>{for (final k in order) k: []};

    for (final n in _items) {
      final d = _notifDate(n);
      String key;
      if (d == null) {
        key = 'الأقدم';
      } else {
        final day = DateTime(d.year, d.month, d.day);
        if (day == today) {
          key = 'اليوم';
        } else if (day == yesterday) {
          key = 'أمس';
        } else if (d.isAfter(weekStart)) {
          key = 'هذا الأسبوع';
        } else {
          key = 'الأقدم';
        }
      }
      buckets[key]!.add(n);
    }

    return [
      for (final k in order)
        if (buckets[k]!.isNotEmpty) (title: k, items: buckets[k]!),
    ];
  }

  Widget _notificationCard(BuildContext context, Map<String, dynamic> n) {
    final mq = context.mq;
    final id = (n['id'] ?? n['_id'])?.toString() ?? '';
    final title = n['title']?.toString() ?? 'إشعار';
    final message = n['message']?.toString() ?? '';
    final payload = _parsePayload(n);
    final senderName = payload['sender'] is Map ? (payload['sender']['name']?.toString() ?? '') : '';
    final d = _notifDate(n);
    final time = d != null ? _formatDate(d.toIso8601String()) : '';
    final unread = _isUnread(n);
    final style = _typeStyle(context, n);

    return MqCard(
      bordered: true,
      color: unread ? mq.accentSoft.withValues(alpha: 0.5) : mq.card,
      padding: const EdgeInsets.all(MqSpacing.md),
      onTap: () {
        final idx = _items.indexWhere((e) => (e['id'] ?? e['_id']) == id);
        if (idx != -1) {
          final current = _items[idx];
          final alreadyRead = current['isRead'] == true || current['readAt'] != null || current['status'] == 'read';
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), borderRadius: MqRadius.brMd),
            child: Icon(style.icon, color: style.color, size: MqSize.iconMd),
          ),
          MqSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unread) ...[
                      MqSpacing.gapXs,
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: mq.accent, shape: BoxShape.circle)),
                    ],
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(message, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                MqSpacing.gapSm,
                Row(
                  children: [
                    MqBadge(label: style.label, tone: MqBadgeTone.accent, icon: style.icon),
                    const Spacer(),
                    if (senderName.isNotEmpty) ...[
                      Icon(Icons.person_outline_rounded, size: 12, color: mq.ink3),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(senderName, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      MqSpacing.gapSm,
                    ],
                    Icon(Icons.schedule_rounded, size: 12, color: mq.ink3),
                    const SizedBox(width: 3),
                    Text(time, style: context.text.labelSmall),
                  ],
                ),
              ],
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

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(d);

      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
      if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';

      return DateFormat('dd/MM HH:mm').format(d);
    } catch (_) {
      return '';
    }
  }
}
