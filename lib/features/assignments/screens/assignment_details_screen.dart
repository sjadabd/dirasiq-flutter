import 'package:dirasiq/shared/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dirasiq/core/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dirasiq/core/config/app_config.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class AssignmentDetailsScreen extends StatefulWidget {
  final String assignmentId;
  const AssignmentDetailsScreen({super.key, required this.assignmentId});

  @override
  State<AssignmentDetailsScreen> createState() =>
      _AssignmentDetailsScreenState();
}

class _AssignmentDetailsScreenState extends State<AssignmentDetailsScreen> {
  final _api = ApiService();
  Map<String, dynamic>? assignment;
  Map<String, dynamic>? mySubmission;
  bool _loading = true;
  String? _error;
  Timer? _notifTimer;
  bool _gradedNotified = false;
  final bool _enableAutoRefresh = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    if (_enableAutoRefresh) {
      _notifTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _checkGradedNotice();
      });
    }
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkGradedNotice() async {
    final status = (mySubmission?['status']?.toString() ?? '').toLowerCase();
    if (status == 'graded' || _gradedNotified) return;
    try {
      final res = await _api.fetchMyNotifications(
        page: 1,
        limit: 10,
        type: 'homework',
      );
      final data = Map<String, dynamic>.from(res);
      final list = List<Map<String, dynamic>>.from(
        (data['items'] ?? data['notifications'] ?? data['data'] ?? []) as List,
      );
      final aid = widget.assignmentId;
      bool hit = false;
      for (final n in list) {
        final title = (n['title'] ?? '').toString();
        final msg = (n['message'] ?? '').toString();
        final ndata = n['data'] is Map<String, dynamic>
            ? n['data'] as Map<String, dynamic>
            : <String, dynamic>{};
        final nid = (ndata['assignmentId'] ?? ndata['assignment_id'] ?? '')
            .toString();
        if ((title.contains('نتيجة واجبك') || msg.contains('نتيجة واجبك')) &&
            nid == aid) {
          hit = true;
          break;
        }
      }
      if (hit) {
        _gradedNotified = true;
        await _fetch();
      }
    } catch (_) {}
  }

  Future<void> _openViewSubmission() async {
    final assignmentId = assignment?['id']?.toString() ?? widget.assignmentId;
    Map<String, dynamic>? sub;
    try {
      sub = await _api.fetchMyAssignmentSubmission(assignmentId);
    } catch (e) {
      sub = mySubmission;
      _showMessage(_cleanErrorMessage(e));
    }
    if (sub == null) {
      _showMessage('لا يوجد تسليم لعرضه');
      return;
    }
    if (mounted) {
      setState(() => mySubmission = sub);
    }

    final theme = Theme.of(context);
    final String contentText = (sub['content_text']?.toString() ?? '').trim();
    final String linkUrl = (sub['link_url']?.toString() ?? '').trim();
    final List atts = (sub['attachments'] is List)
        ? List.from(sub['attachments'])
        : const [];

    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.tertiary, AppColors.tertiary],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'إجابتي',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (contentText.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.text_fields_rounded,
                                size: 14,
                                color: AppColors.tertiary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'النص:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            contentText,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (linkUrl.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: 14,
                                color: AppColors.info,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'الرابط:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _launchUrl(_toAbsoluteUrl(linkUrl)),
                            child: Text(
                              linkUrl,
                              style: const TextStyle(
                                color: AppColors.info,
                                fontSize: 11,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (atts.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.attach_file_rounded,
                                size: 14,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'المرفقات:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...atts.map((a) {
                            if (a is! Map) return const SizedBox.shrink();
                            final String type = (a['type']?.toString() ?? '')
                                .toLowerCase();
                            final String name = a['name']?.toString() ?? 'ملف';
                            final String url = (a['url']?.toString() ?? '')
                                .trim();
                            final String base64 =
                                (a['base64']?.toString() ?? '').trim();

                            if (type == 'image') {
                              Widget? imageWidget;
                              if (url.isNotEmpty) {
                                final abs = _toAbsoluteUrl(url);
                                imageWidget = GestureDetector(
                                  onTap: () => _openImagePreview(abs),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      abs,
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 120,
                                        color: theme.colorScheme.surfaceVariant,
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 36,
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              } else if (base64.isNotEmpty) {
                                final bytes = UriData.parse(
                                  base64,
                                ).contentAsBytes();
                                imageWidget = GestureDetector(
                                  onTap: () async {
                                    await showDialog(
                                      context: context,
                                      builder: (c2) => Dialog(
                                        insetPadding: const EdgeInsets.all(12),
                                        child: InteractiveViewer(
                                          minScale: 0.5,
                                          maxScale: 4,
                                          child: Image.memory(
                                            bytes,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      bytes,
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              }
                              if (imageWidget == null)
                                return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: imageWidget,
                              );
                            }

                            final IconData icon = type == 'pdf'
                                ? Icons.picture_as_pdf_rounded
                                : Icons.insert_drive_file_rounded;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceVariant
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    icon,
                                    size: 16,
                                    color: type == 'pdf'
                                        ? AppColors.error
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      if (url.isNotEmpty) {
                                        _launchUrl(_toAbsoluteUrl(url));
                                      } else if (base64.isNotEmpty) {
                                        _showMessage(
                                          'لا يمكن فتح الملف المضغوط هنا',
                                        );
                                      } else {
                                        _showMessage('لا يمكن فتح المرفق');
                                      }
                                    },
                                    icon: Icon(
                                      Icons.open_in_new_rounded,
                                      size: 16,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                        if (contentText.isEmpty &&
                            linkUrl.isEmpty &&
                            atts.isEmpty)
                          const Text(
                            'لا توجد تفاصيل للإجابة.',
                            style: TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
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
        );
      },
    );
  }

  String _toAbsoluteUrl(String raw) {
    var s = (raw).trim();
    if (s.isEmpty) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final base = AppConfig.serverBaseUrl.replaceAll(RegExp(r"/+$"), '');
    if (!s.startsWith('/')) s = '/$s';
    return '$base$s';
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
                  errorBuilder: (_, __, ___) => Container(
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

  Future<void> _openSubmitBottomSheet() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final assignmentId = assignment?['id']?.toString() ?? widget.assignmentId;

    Map<String, dynamic>? existing;
    try {
      existing = await _api.fetchMyAssignmentSubmission(assignmentId);
    } catch (e) {
      _showMessage(_cleanErrorMessage(e));
    }

    final contentController = TextEditingController(
      text: existing?['content_text']?.toString() ?? '',
    );
    final linkController = TextEditingController(
      text: existing?['link_url']?.toString() ?? '',
    );
    String status = (existing?['status']?.toString() ?? 'submitted');

    String submissionType =
        (assignment?['submission_type']?.toString() ??
                assignment?['submissionType']?.toString() ??
                '')
            .toLowerCase();
    const allowedTypes = {'text', 'link', 'file', 'mixed'};
    if (!allowedTypes.contains(submissionType) ||
        submissionType == 'electronic' ||
        submissionType == 'online') {
      submissionType = 'mixed';
    }

    final assignedIso =
        (assignment?['assigned_date'] ??
                assignment?['assigned_at'] ??
                assignment?['assignedAt'])
            ?.toString();
    final dueIso =
        (assignment?['due_date'] ??
                assignment?['due_at'] ??
                assignment?['dueAt'])
            ?.toString();
    final bool isActive =
        (assignment?['is_active'] == true) || (assignment?['isActive'] == true);

    DateTime? assignedAt;
    DateTime? dueAt;
    try {
      assignedAt = assignedIso != null
          ? DateTime.parse(assignedIso).toLocal()
          : null;
    } catch (_) {}
    try {
      dueAt = dueIso != null ? DateTime.parse(dueIso).toLocal() : null;
    } catch (_) {}

    bool submitting = false;
    final List<Map<String, dynamic>> attachments = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
            left: 14,
            right: 14,
            top: 14,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              final bool showText =
                  submissionType == 'text' || submissionType == 'mixed';
              final bool showLink =
                  submissionType == 'link' || submissionType == 'mixed';
              final bool showFiles =
                  submissionType == 'file' || submissionType == 'mixed';

              Future<void> _pickFiles({required bool images}) async {
                try {
                  final res = await FilePicker.platform.pickFiles(
                    type: images ? FileType.image : FileType.custom,
                    allowMultiple: true,
                    allowedExtensions: images ? null : ['pdf'],
                    withData: true,
                  );
                  if (res == null) return;
                  for (final f in res.files) {
                    final name = f.name;
                    final ext = (f.extension ?? '').toLowerCase();
                    final bytes =
                        f.bytes ??
                        (f.path != null
                            ? await File(f.path!).readAsBytes()
                            : null);
                    if (bytes == null) continue;
                    final b64 = base64Encode(bytes);
                    String type;
                    String mime;
                    if (images ||
                        ext == 'png' ||
                        ext == 'jpg' ||
                        ext == 'jpeg') {
                      type = 'image';
                      mime = ext == 'png' ? 'image/png' : 'image/jpeg';
                    } else {
                      type = 'pdf';
                      mime = 'application/pdf';
                    }
                    final dataUri = 'data:$mime;base64,$b64';
                    setModal(() {
                      attachments.add({
                        'type': type,
                        'name': name,
                        'base64': dataUri,
                      });
                    });
                  }
                } catch (e) {
                  _showMessage('فشل اختيار الملفات: $e');
                }
              }

              String? validateInputs() {
                if (!isActive) return 'الواجب غير مفعّل حالياً';
                final now = DateTime.now();
                if (assignedAt != null && now.isBefore(assignedAt))
                  return 'لم يبدأ وقت التسليم بعد';
                if (dueAt != null && now.isAfter(dueAt))
                  return 'انتهى وقت التسليم';

                final textVal = contentController.text.trim();
                final linkVal = linkController.text.trim();
                final hasText = textVal.isNotEmpty;
                final hasLink = linkVal.isNotEmpty;
                final hasFiles = attachments.isNotEmpty;
                final hasAny = hasText || hasLink || hasFiles;

                switch (submissionType) {
                  case 'text':
                    if (!hasText)
                      return 'نوع التسليم نصي، يرجى إدخال نص الإجابة';
                    break;
                  case 'link':
                    if (!hasLink)
                      return 'نوع التسليم رابط، يرجى إدخال رابط صحيح';
                    break;
                  case 'file':
                    if (!hasFiles)
                      return 'هذا الواجب يتطلب رفع ملفات (صورة أو PDF)';
                    break;
                  case 'mixed':
                    if (!hasAny)
                      return 'يرجى إدخال نص أو رابط (أو مرفقات) للتسليم';
                    break;
                }
                return null;
              }

              Future<void> doSubmit() async {
                if (submitting) return;
                final err = validateInputs();
                if (err != null) {
                  _showMessage(err);
                  return;
                }
                setModal(() => submitting = true);
                try {
                  final res = await _api.submitAssignment(
                    assignmentId: assignmentId,
                    contentText: contentController.text.trim().isEmpty
                        ? null
                        : contentController.text.trim(),
                    linkUrl: linkController.text.trim().isEmpty
                        ? null
                        : linkController.text.trim(),
                    attachments: attachments,
                    status: status.isEmpty ? 'submitted' : status,
                  );
                  final data = res['data'] is Map<String, dynamic>
                      ? Map<String, dynamic>.from(res['data'])
                      : null;
                  if (data != null) {
                    setState(() => mySubmission = data);
                  }
                  if (mounted) Navigator.of(ctx).pop();
                  _showMessage('تم إرسال الإجابة بنجاح');
                  await _fetch();
                } catch (e) {
                  _showMessage(_cleanErrorMessage(e));
                } finally {
                  if (mounted) setModal(() => submitting = false);
                }
              }

              return SizedBox(
                width: double.infinity,
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
                                colors: [
                                  AppColors.primary,
                                  AppColors.secondary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.assignment_turned_in_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'إرسال إجابتي',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (showText) ...[
                        TextField(
                          controller: contentController,
                          maxLines: 4,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'نص الإجابة',
                            labelStyle: const TextStyle(fontSize: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (showLink) ...[
                        TextField(
                          controller: linkController,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'رابط خارجي',
                            labelStyle: const TextStyle(fontSize: 12),
                            hintText: 'https://...',
                            hintStyle: const TextStyle(fontSize: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (showFiles)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(
                              0.3,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.attach_file_rounded,
                                    size: 14,
                                    color: AppColors.tertiary,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'المرفقات (اختياري)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _pickFiles(images: true),
                                    icon: const Icon(
                                      Icons.image_rounded,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'صورة',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      minimumSize: const Size(0, 32),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _pickFiles(images: false),
                                    icon: const Icon(
                                      Icons.picture_as_pdf_rounded,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'PDF',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      minimumSize: const Size(0, 32),
                                    ),
                                  ),
                                ],
                              ),
                              if (attachments.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: attachments.asMap().entries.map((
                                    e,
                                  ) {
                                    final i = e.key;
                                    final it = e.value;
                                    final name = (it['name'] ?? 'ملف')
                                        .toString();
                                    final type = (it['type'] ?? '').toString();
                                    return Chip(
                                      label: Text(
                                        name,
                                        style: const TextStyle(fontSize: 10),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      avatar: Icon(
                                        type == 'pdf'
                                            ? Icons.picture_as_pdf_rounded
                                            : Icons.image_rounded,
                                        size: 14,
                                      ),
                                      deleteIcon: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                      ),
                                      onDeleted: () => setModal(
                                        () => attachments.removeAt(i),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),

                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'الحالة:',
                                style: TextStyle(fontSize: 11),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<String>(
                                  value: status,
                                  underline: const SizedBox.shrink(),
                                  isDense: true,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'submitted',
                                      child: Text('مُسَلَّم'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'pending',
                                      child: Text('قيد المراجعة'),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setModal(() => status = v ?? 'submitted'),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: submitting
                                    ? null
                                    : () => Navigator.of(ctx).pop(),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: const Size(0, 32),
                                ),
                                child: const Text(
                                  'إلغاء',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                onPressed: submitting ? null : doSubmit,
                                icon: submitting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, size: 14),
                                label: const Text(
                                  'إرسال',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: const Size(0, 32),
                                  backgroundColor: AppColors.tertiary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCompactEvaluationCard(ThemeData theme, bool isDark) {
    final sub = mySubmission;
    if (sub == null) return const SizedBox.shrink();

    final maxScore = assignment?['max_score'];
    final score = sub['score'];
    final feedback = (sub['feedback']?.toString() ?? '').trim();
    final status = (sub['status']?.toString() ?? '').toLowerCase();

    IconData icon;
    Color color;
    String statusLabel;
    switch (status) {
      case 'graded':
        icon = Icons.check_circle_rounded;
        color = AppColors.success;
        statusLabel = 'مُقَيَّم';
        break;
      case 'submitted':
        icon = Icons.upload_file_rounded;
        color = AppColors.info;
        statusLabel = 'مُسَلَّم';
        break;
      case 'pending':
        icon = Icons.hourglass_bottom_rounded;
        color = AppColors.warning;
        statusLabel = 'قيد المراجعة';
        break;
      case 'rejected':
        icon = Icons.cancel_rounded;
        color = AppColors.error;
        statusLabel = 'مرفوض';
        break;
      default:
        icon = Icons.info_rounded;
        color = theme.colorScheme.outline;
        statusLabel = status.isEmpty ? '-' : status;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'تقييم المعلم',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCompactInfoRow(
            theme,
            Icons.star_rounded,
            'الدرجة',
            (score != null && maxScore != null)
                ? '$score / $maxScore'
                : (score?.toString() ?? '-'),
            AppColors.warning,
          ),
          const SizedBox(height: 6),
          _buildCompactInfoRow(
            theme,
            Icons.assignment_turned_in_rounded,
            'الحالة',
            statusLabel,
            color,
          ),
          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.comment_rounded, size: 14, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ملاحظة المعلم',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(feedback, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _fetch() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final res = await _api.fetchAssignmentById(widget.assignmentId);
      final data = res['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(res['data'])
          : <String, dynamic>{};
      final sub = res['mySubmission'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(res['mySubmission'])
          : null;
      setState(() {
        assignment = data;
        mySubmission = sub;
        _loading = false;
      });
    } catch (e) {
      final msg = _cleanErrorMessage(e);
      setState(() {
        _error = msg;
        _loading = false;
      });
      _showMessage(msg);
    }
  }

  String _cleanErrorMessage(Object e) {
    var s = e.toString();
    s = s.replaceFirst(RegExp(r'^Exception:\s*'), '');
    s = s.replaceFirst(RegExp(r'^DioException.*?:\s*'), '');
    if (s.trim().isEmpty) return 'حدث خطأ غير متوقع';
    return s;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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

  String _getSubmissionTypeLabel(String? type) {
    switch (type) {
      case 'online':
        return 'إلكتروني';
      case 'physical':
        return 'ورقي';
      case 'mixed':
        return 'مختلط';
      default:
        return type ?? '-';
    }
  }

  Color _getSubmissionTypeColor(String? type) {
    switch (type) {
      case 'online':
      case 'physical':
        return AppColors.warning;
      case 'mixed':
        return AppColors.secondary;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('لا يمكن فتح الرابط'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في فتح الرابط: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildCompactHeader(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.tertiary, AppColors.tertiary],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.tertiary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  assignment!['title']?.toString() ?? 'واجب',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if ((assignment!['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              assignment!['description'].toString(),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactInfoCard(ThemeData theme, bool isDark) {
    final assignedDate = assignment!['assigned_date'];
    final dueDate = assignment!['due_date'];
    final submissionType = assignment!['submission_type'];
    final maxScore = assignment!['max_score'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'معلومات الواجب',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildCompactInfoRow(
            theme,
            Icons.calendar_today_rounded,
            'تاريخ الإسناد',
            _formatDate(assignedDate?.toString()),
            AppColors.info,
          ),
          const SizedBox(height: 6),
          _buildCompactInfoRow(
            theme,
            Icons.event_rounded,
            'تاريخ التسليم',
            _formatDate(dueDate?.toString()),
            AppColors.error,
          ),
          const SizedBox(height: 6),
          _buildCompactInfoRow(
            theme,
            Icons.upload_file_rounded,
            'نوع التسليم',
            _getSubmissionTypeLabel(submissionType?.toString()),
            _getSubmissionTypeColor(submissionType?.toString()),
          ),
          const SizedBox(height: 6),
          _buildCompactInfoRow(
            theme,
            Icons.star_rounded,
            'الدرجة القصوى',
            maxScore?.toString() ?? '-',
            AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
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
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactAttachmentsCard(ThemeData theme, bool isDark) {
    final attachments = assignment!['attachments'];
    if (attachments == null || attachments is! Map)
      return const SizedBox.shrink();

    final files = attachments['files'];
    if (files == null || files is! List || files.isEmpty)
      return const SizedBox.shrink();

    final List images = files
        .where(
          (f) => (f is Map) && (f['type']?.toString().toLowerCase() == 'image'),
        )
        .toList();
    final List others = files
        .where(
          (f) =>
              !(f is Map && (f['type']?.toString().toLowerCase() == 'image')),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file_rounded,
                color: AppColors.tertiary,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'المرفقات',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (images.isNotEmpty) ...[
            const Text(
              'الصور',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1,
              ),
              itemCount: images.length,
              itemBuilder: (_, i) {
                final it = images[i] as Map;
                final imgUrl = _toAbsoluteUrl((it['url'] ?? '').toString());
                return GestureDetector(
                  onTap: () => _openImagePreview(imgUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: theme.colorScheme.surfaceVariant,
                        child: Icon(
                          Icons.broken_image,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],

          if (others.isNotEmpty) ...[
            const Text(
              'ملفات',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            ),
            const SizedBox(height: 6),
            ...others.map((file) => _buildCompactAttachmentItem(file, theme)),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactAttachmentItem(dynamic file, ThemeData theme) {
    if (file is! Map) return const SizedBox.shrink();

    final url = file['url']?.toString() ?? '';
    final name = file['name']?.toString() ?? 'ملف';
    final type = file['type']?.toString() ?? '';

    IconData icon;
    Color color;

    if (type == 'image') {
      return const SizedBox.shrink();
    } else if (type == 'pdf') {
      icon = Icons.picture_as_pdf_rounded;
      color = AppColors.error;
    } else {
      icon = Icons.insert_drive_file_rounded;
      color = theme.colorScheme.onSurfaceVariant;
    }

    final absUrl = _toAbsoluteUrl(url);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => _launchUrl(absUrl),
            icon: Icon(
              type.toLowerCase() == 'pdf'
                  ? Icons.picture_as_pdf_rounded
                  : Icons.open_in_new_rounded,
              size: 16,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactResourcesCard(ThemeData theme, bool isDark) {
    final resources = assignment!['resources'];
    if (resources == null || resources is! List || resources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, color: AppColors.info, size: 16),
              const SizedBox(width: 6),
              const Text(
                'المصادر والروابط',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...resources.map(
            (resource) => _buildCompactResourceItem(resource, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactResourceItem(dynamic resource, ThemeData theme) {
    if (resource is! Map) return const SizedBox.shrink();

    final url = resource['url']?.toString() ?? '';
    final title = resource['title']?.toString() ?? 'رابط';
    final type = resource['type']?.toString() ?? 'link';

    IconData leadIcon;
    Color leadColor;
    switch (type.toLowerCase()) {
      case 'video':
        leadIcon = Icons.play_circle_outline_rounded;
        leadColor = AppColors.error;
        break;
      case 'pdf':
        leadIcon = Icons.picture_as_pdf_rounded;
        leadColor = AppColors.error;
        break;
      case 'image':
        leadIcon = Icons.image_rounded;
        leadColor = AppColors.success;
        break;
      case 'doc':
      case 'article':
        leadIcon = Icons.description_rounded;
        leadColor = AppColors.warning;
        break;
      case 'link':
      default:
        leadIcon = Icons.link_rounded;
        leadColor = AppColors.info;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [leadColor.withOpacity(0.1), leadColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchUrl(_toAbsoluteUrl(url)),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: leadColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(leadIcon, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        url,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.open_in_new_rounded, size: 14, color: leadColor),
              ],
            ),
          ),
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
      appBar: AppBar(
        title: const Text('تفاصيل الواجب', style: TextStyle(fontSize: 16)),
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.tertiary,
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
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.errorLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _fetch,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'إعادة المحاولة',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : assignment == null
          ? const Center(
              child: Text('لا توجد بيانات', style: TextStyle(fontSize: 13)),
            )
          : RefreshIndicator(
              onRefresh: _fetch,
              color: AppColors.tertiary,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildCompactHeader(theme, isDark),
                  const SizedBox(height: 10),
                  _buildCompactInfoCard(theme, isDark),
                  const SizedBox(height: 10),
                  _buildCompactAttachmentsCard(theme, isDark),
                  const SizedBox(height: 10),
                  _buildCompactResourcesCard(theme, isDark),
                  const SizedBox(height: 10),
                  _buildCompactEvaluationCard(theme, isDark),

                  if ((() {
                    String deliveryMode = '';
                    final atts = assignment?['attachments'];
                    if (atts is Map) {
                      final meta = atts['meta'];
                      if (meta is Map) {
                        deliveryMode =
                            (meta['delivery_mode'] ??
                                    meta['deliveryMode'] ??
                                    '')
                                .toString()
                                .toLowerCase();
                      }
                    }
                    if (mySubmission == null) return false;
                    if (deliveryMode == 'paper') {
                      final content =
                          (mySubmission?['content_text']?.toString() ?? '')
                              .trim();
                      final link = (mySubmission?['link_url']?.toString() ?? '')
                          .trim();
                      final sAtts = mySubmission?['attachments'];
                      final hasAtts = sAtts is List && sAtts.isNotEmpty;
                      return content.isNotEmpty || link.isNotEmpty || hasAtts;
                    }
                    return true;
                  })()) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openViewSubmission,
                        icon: const Icon(Icons.visibility_rounded, size: 16),
                        label: const Text(
                          'عرض إجابتي',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  if ((() {
                    final status = (mySubmission?['status']?.toString() ?? '')
                        .toLowerCase();
                    final isGraded = status == 'graded';
                    String deliveryMode = '';
                    final atts = assignment?['attachments'];
                    if (atts is Map) {
                      final meta = atts['meta'];
                      if (meta is Map) {
                        deliveryMode =
                            (meta['delivery_mode'] ??
                                    meta['deliveryMode'] ??
                                    '')
                                .toString()
                                .toLowerCase();
                      }
                    }
                    final isPaper = deliveryMode == 'paper';
                    return !(isGraded || isPaper);
                  })())
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openSubmitBottomSheet,
                        icon: const Icon(
                          Icons.assignment_turned_in_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'إرسال إجابتي',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: AppColors.tertiary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
