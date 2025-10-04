import 'dart:convert';
import 'package:dirasiq/features/bookings/screens/booking_details_screen.dart';
import 'package:dirasiq/shared/themes/app_colors.dart';
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

  static const List<Map<String, dynamic>> _filters = [
    {"text": "الكل", "value": null, "icon": Icons.notifications_rounded},
    {"text": "واجب", "value": "homework", "icon": Icons.assignment_rounded},
    {"text": "رسالة", "value": "message", "icon": Icons.message_rounded},
    {"text": "تقرير", "value": "report", "icon": Icons.description_rounded},
    {"text": "تبليغ", "value": "notice", "icon": Icons.campaign_rounded},
    {"text": "أقساط", "value": "installments", "icon": Icons.payments_rounded},
    {
      "text": "حضور",
      "value": "attendance",
      "icon": Icons.event_available_rounded,
    },
    {"text": "ملخص", "value": "daily_summary", "icon": Icons.summarize_rounded},
    {"text": "أعياد", "value": "birthday", "icon": Icons.cake_rounded},
    {"text": "امتحان", "value": "daily_exam", "icon": Icons.quiz_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
    _scroll.addListener(_onScroll);
    _setupNotificationListeners();
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

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact Header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primary],
                    ),
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
                              color: AppColors.primary,
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
                                color: AppColors.primary,
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
                                color: AppColors.secondary,
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
                                        color: AppColors.primary.withValues(
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
                                color: AppColors.error,
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
                                theme: theme,
                              ),
                            );
                          }),
                        ],

                        if (link != null && link.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildCompactLinkButton(link: link, theme: theme),
                        ],

                        if (studyYear != null && studyYear.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.school_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'السنة: $studyYear',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
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
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'إغلاق',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _openNotificationTarget(n);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'التفاصيل',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactPdfButton({
    required String pdfUrl,
    required String label,
    required ThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchUrl(pdfUrl),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                size: 16,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.error),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactLinkButton({
    required String link,
    required ThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _launchUrl(link),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, size: 16, color: AppColors.info),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'فتح الرابط',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.info),
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

    // Booking status routing
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: const GlobalAppBar(title: 'الإشعارات', centerTitle: true),
      body: Column(
        children: [
          _buildFiltersSection(theme),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetch(refresh: true),
              color: AppColors.primary,
              child: _buildBody(theme, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _buildFilterChip(_filters[i], theme),
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }

  Widget _buildFilterChip(Map<String, dynamic> filter, ThemeData theme) {
    final val = filter['value'];
    final selected = _typeFilter == val;
    final icon = filter['icon'] as IconData?;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _typeFilter = val);
          _fetch(refresh: true);
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.primary],
                  )
                : null,
            color: selected ? null : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : theme.colorScheme.outlineVariant,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                filter['text'] ?? '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_loading && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'جاري التحميل...',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'حدث خطأ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _fetch(refresh: true),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_off_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد إشعارات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'لم نجد أي إشعارات لهذا الفلتر',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _buildCompactNotificationCard(_items[index], theme, isDark);
      },
    );
  }

  Widget _buildCompactNotificationCard(
    Map<String, dynamic> n,
    ThemeData theme,
    bool isDark,
  ) {
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
    final createdAt =
        (n['createdAt']?.toString() ??
        n['created_at']?.toString() ??
        n['timestamp']?.toString() ??
        n['time']?.toString() ??
        _parsePayload(n)['createdAt']?.toString() ??
        _parsePayload(n)['created_at']?.toString());
    final time = createdAt != null && createdAt.isNotEmpty
        ? _formatDate(createdAt)
        : '';
    final isUnread = !(isReadFlag || readAtVal != null || status == 'read');

    return Material(
      color: Colors.transparent,
      child: InkWell(
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnread
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isUnread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isUnread
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: isUnread ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: isUnread
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.primary],
                        )
                      : null,
                  color: isUnread
                      ? null
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isUnread
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: isUnread
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (message.isNotEmpty || senderName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      if (message.isNotEmpty)
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (senderName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 10,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                senderName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
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
